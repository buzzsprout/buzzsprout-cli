# frozen_string_literal: true

require 'json'
require 'net/http'
require 'openssl'
require 'uri'
require_relative 'version'
require_relative 'redact'

module Buzzsprout
  class Client
    USER_AGENT = "BuzzsproutCLI/#{VERSION}"
    MAX_RETRIES = 5
    OPEN_TIMEOUT = 15
    READ_TIMEOUT = 60

    class Error < StandardError
      attr_reader :status, :body, :error_code, :param, :headers

      def initialize(message, status: nil, body: nil, error_code: nil, param: nil, headers: nil)
        super(message)
        @status = status
        @body = body
        @error_code = error_code
        @param = param
        @headers = headers || {}
      end
    end

    class NotModified < Error; end
    class Unauthorized < Error; end
    class RateLimited < Error; end

    Response = Struct.new(:status, :body, :headers, :parsed, :not_modified, keyword_init: true) do
      def success?
        status.between?(200, 299)
      end

      def [](key)
        headers[key.to_s.downcase]
      end
    end

    def initialize(token:, base_url: nil, dry_run: false, transport: nil, io: $stderr)
      @token = token
      @base_url = (base_url || Config.api_base_url).to_s.chomp('/')
      @dry_run = dry_run
      @transport = transport
      @io = io
      @etag_store = {}
    end

    def get(path, query: {}, use_etag: true)
      request(:get, path, query: query, use_etag: use_etag)
    end

    def post(path, body: nil, query: {}, headers: {}, multipart: nil)
      request(:post, path, body: body, query: query, headers: headers, multipart: multipart)
    end

    def put(path, body: nil, headers: {})
      request(:put, path, body: body, headers: headers)
    end

    def patch(path, body: nil)
      request(:patch, path, body: body)
    end

    def delete(path)
      request(:delete, path)
    end

      def put_bytes(url, bytes, headers: {})
      uri = URI(url)
      request_headers = {
        'Content-Length' => bytes.bytesize.to_s,
        'User-Agent' => USER_AGENT
      }
      request_headers.merge!(headers)
      raw = transport.request(:put, uri, request_headers, bytes)
      raise_for_status(raw) unless raw.status.between?(200, 299)
      raw
    end

    def request(method, path, body: nil, query: {}, headers: {}, use_etag: false, multipart: nil)
      uri = build_uri(path, query)

      if @dry_run
        print_dry_run(method, uri, body, multipart)
        return nil
      end

      retries = 0
      loop do
        req_headers = default_headers
        req_headers['Content-Type'] = 'application/json; charset=utf-8' if body && multipart.nil?
        req_headers.merge!(headers)

        encoded_body = if multipart
                         encoded, content_type = encode_multipart(multipart)
                         req_headers['Content-Type'] = content_type
                         encoded
                       elsif body.nil?
                         nil
                       elsif body.is_a?(String)
                         body
                       else
                         JSON.generate(body)
                       end

        if use_etag && method == :get && (etag = @etag_store.dig(uri.to_s, :etag))
          req_headers['If-None-Match'] = etag
        end

        raw = transport.request(method, uri, req_headers, encoded_body)

        if raw.status == 429 && retries < MAX_RETRIES
          retries += 1
          sleep backoff_seconds(raw, retries)
          next
        end

        if raw.status.between?(500, 599) && retries < MAX_RETRIES && method == :get
          retries += 1
          sleep backoff_seconds(raw, retries)
          next
        end

        if raw.status == 304
          cached = @etag_store.dig(uri.to_s, :body)
          return cached unless cached.nil?

          raise NotModified.new('Not modified', status: 304, headers: raw.headers)
        end

        raise_for_status(raw) unless raw.status.between?(200, 299)

        parsed = parse_body(raw.body)
        if (etag = raw.headers['etag'])
          @etag_store[uri.to_s] = { etag: etag, body: parsed }
        end
        return parsed
      end
    end

    private

    def transport
      @transport || NetTransport.new
    end

    def default_headers
      {
        'Authorization' => "Token token=#{@token}",
        'User-Agent' => USER_AGENT,
        'Accept' => 'application/json'
      }
    end

    def build_uri(path, query)
      if path.to_s.start_with?('http://', 'https://')
        uri = URI(path)
      else
        suffix = path.to_s.start_with?('/') ? path : "/#{path}"
        uri = URI("#{@base_url}#{suffix}")
      end

      unless query.nil? || query.empty?
        existing = URI.decode_www_form(uri.query || '')
        query.each do |key, value|
          next if value.nil? || Redact::QUERY_KEYS.match?(key.to_s)

          existing << [key.to_s, value.to_s]
        end
        uri.query = URI.encode_www_form(existing) unless existing.empty?
      end
      uri
    end

    def parse_body(body)
      return nil if body.nil? || body.empty?

      JSON.parse(body)
    rescue JSON::ParserError
      body
    end

    def raise_for_status(raw)
      parsed = parse_error(raw)
      message = Redact.string(parsed[:message], known: @token)
      klass = case raw.status
              when 401 then Unauthorized
              when 429 then RateLimited
              else Error
              end
      raise klass.new(message, status: raw.status, body: raw.body, error_code: parsed[:code], param: parsed[:param], headers: raw.headers)
    end

    def parse_error(raw)
      data = parse_body(raw.body)
      if data.is_a?(Hash) && data['error'].is_a?(Hash)
        err = data['error']
        message = err['message'] || 'API error'
        message = "#{message} (#{err['param']})" if err['param']
        return { message: "API error #{raw.status}: #{message}", code: err['code'], param: err['param'] }
      end

      if data.is_a?(Hash) && data.values.any? { |value| value.is_a?(Array) }
        details = data.map { |key, value| "#{key}: #{Array(value).join(', ')}" }.join('; ')
        return { message: "API error #{raw.status}: #{details}", code: 'invalid', param: nil }
      end

      snippet = raw.body.to_s.strip
      snippet = snippet[0, 400] unless snippet.empty?
      snippet = raw.headers['status'] || 'request failed' if snippet.empty?
      { message: "API error #{raw.status}: #{snippet}", code: nil, param: nil }
    end

    def backoff_seconds(raw, retries)
      retry_after = raw.headers['retry-after']
      return retry_after.to_f if retry_after.to_s =~ /\A\d+(\.\d+)?\z/

      [2**retries, 16].min
    end

    def print_dry_run(method, uri, body, multipart)
      @io.puts Redact.string("[dry-run] #{method.to_s.upcase} #{Redact.uri(uri, known: @token)}", known: @token)
      @io.puts "[dry-run] Authorization: Token token=#{Redact::PLACEHOLDER}"
      @io.puts "[dry-run] User-Agent: #{USER_AGENT}"
      if body
        payload = body.is_a?(String) ? body : JSON.pretty_generate(body)
        @io.puts Redact.string("[dry-run] body: #{payload}", known: @token)
      end
      @io.puts "[dry-run] multipart: #{multipart.keys.join(', ')}" if multipart
    end

    def encode_multipart(parts)
      boundary = "buzzsprout#{Time.now.to_i}#{rand(1_000_000)}"
      chunks = []
      parts.each do |name, value|
        chunks << "--#{boundary}\r\n"
        if value.is_a?(Hash) && value[:filename]
          chunks << "Content-Disposition: form-data; name=\"#{name}\"; filename=\"#{value[:filename]}\"\r\n"
          chunks << "Content-Type: #{value[:content_type] || 'application/octet-stream'}\r\n\r\n"
          chunks << value[:data]
          chunks << "\r\n"
        else
          chunks << "Content-Disposition: form-data; name=\"#{name}\"\r\n\r\n"
          chunks << value.to_s
          chunks << "\r\n"
        end
      end
      chunks << "--#{boundary}--\r\n"
      [chunks.join, "multipart/form-data; boundary=#{boundary}"]
    end

    class NetTransport
      Raw = Struct.new(:status, :body, :headers, keyword_init: true)

      def request(method, uri, headers, body)
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = uri.scheme == 'https'
        http.verify_mode = OpenSSL::SSL::VERIFY_PEER if http.use_ssl?
        http.open_timeout = OPEN_TIMEOUT
        http.read_timeout = READ_TIMEOUT

        request = build_request(method, uri)
        headers.each { |key, value| request[key] = value }
        request.body = body unless body.nil?

        response = http.request(request)
        header_hash = {}
        response.each_header { |key, value| header_hash[key.downcase] = value }
        Raw.new(status: response.code.to_i, body: response.body, headers: header_hash)
      end

      private

      def build_request(method, uri)
        klass = case method
                when :get then Net::HTTP::Get
                when :post then Net::HTTP::Post
                when :put then Net::HTTP::Put
                when :patch then Net::HTTP::Patch
                when :delete then Net::HTTP::Delete
                else
                  raise ArgumentError, "Unsupported HTTP method: #{method}"
                end
        klass.new(uri.request_uri)
      end
    end
  end
end

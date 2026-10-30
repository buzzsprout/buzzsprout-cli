# frozen_string_literal: true

require 'net/http'
require 'socket'
require 'securerandom'
require 'digest'
require 'timeout'

module Buzzsprout
  module OAuth
    CLIENT_ID = ''.freeze # Set to the registered public CLI application ID before release.
    CALLBACK_PATH = '/oauth/callback'
    module_function

    def issuer
      uri = URI(Config.api_base_url)
      raise 'Invalid API URL' unless %w[https http].include?(uri.scheme) && uri.host && !uri.userinfo
      "#{uri.scheme}://#{uri.host}#{uri.port == uri.default_port ? '' : ":#{uri.port}"}"
    end

    def client_id
      ENV['BUZZSPROUT_OAUTH_CLIENT_ID'].to_s.empty? ? CLIENT_ID : ENV['BUZZSPROUT_OAUTH_CLIENT_ID']
    end

    def token_request(parameters, server: issuer)
      uri = URI("#{server}/oauth/token")
      request = Net::HTTP::Post.new(uri)
      request['User-Agent'] = Client::USER_AGENT
      request['Accept'] = 'application/json'
      request.set_form_data(parameters)
      response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == 'https', open_timeout: 15, read_timeout: 30) { |http| http.request(request) }
      raise "OAuth authorization failed. Run 'buzzsprout login' to reconnect." unless response.is_a?(Net::HTTPSuccess)
      data = JSON.parse(response.body)
      unless data.is_a?(Hash) && data['access_token'].is_a?(String) && !data['access_token'].empty? && data['refresh_token'].is_a?(String) && !data['refresh_token'].empty? && data['token_type'].to_s.downcase == 'bearer' && data['expires_in'].to_i.positive?
        raise 'Invalid OAuth token response. Run buzzsprout login again.'
      end
      { access_token: data['access_token'], refresh_token: data['refresh_token'], expires_at: Time.now.to_i + data['expires_in'].to_i }
    rescue JSON::ParserError
      raise 'Invalid OAuth token response. Run buzzsprout login again.'
    end

    def authorize(io:, open_browser: true, timeout: 300)
      id = client_id
      raise 'OAuth client registration is not configured. Set BUZZSPROUT_OAUTH_CLIENT_ID for local testing.' if id.empty?
      server = TCPServer.new('127.0.0.1', 0)
      redirect = "http://127.0.0.1:#{server.addr[1]}#{CALLBACK_PATH}"
      state = SecureRandom.hex(32)
      verifier = SecureRandom.urlsafe_base64(48)
      challenge = [Digest::SHA256.digest(verifier)].pack('m0').tr('+/', '-_').delete('=')
      origin = issuer
      url = "#{origin}/oauth/authorize?#{URI.encode_www_form(response_type: 'code', client_id: id, redirect_uri: redirect, state: state, code_challenge: challenge, code_challenge_method: 'S256')}"
      io.puts "Open this link to connect your Buzzsprout account:\n\n#{url}\n\nWaiting for authorization…"
      io.flush if io.respond_to?(:flush)
      launch_browser(url) if open_browser
      code = wait_for_callback(server, state: state, issuer: origin, timeout: timeout)
      token_request({ grant_type: 'authorization_code', client_id: id, code: code, redirect_uri: redirect, code_verifier: verifier }, server: origin).merge(client_id: id, issuer: origin, api_base: Config.api_base_url)
    rescue Interrupt
      raise 'Authorization cancelled. Run buzzsprout login to try again.'
    ensure
      server&.close
    end

    def wait_for_callback(server, state:, issuer:, timeout:)
      deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + timeout
      loop do
        remaining = deadline - Process.clock_gettime(Process::CLOCK_MONOTONIC)
        raise 'Authorization timed out. Run buzzsprout login again.' unless remaining.positive? && IO.select([server], nil, nil, remaining)
        socket = server.accept
        begin
          line = Timeout.timeout([remaining, 5].min) { socket.gets(8192) }
          method, target, = line.to_s.split(' ')
          uri = URI(target.to_s)
          params = URI.decode_www_form(uri.query.to_s).to_h
          valid = method == 'GET' && uri.path == CALLBACK_PATH && params['state'] == state && params['iss'] == issuer
          code = params['code'] if valid
          denied = valid && params['error']
          message = code && !code.empty? ? 'Authorization received. Return to your terminal to finish connecting.' : 'Authorization could not be completed. Return to your terminal.'
          socket.write "HTTP/1.1 #{valid ? '200 OK' : '400 Bad Request'}\r\nContent-Type: text/plain\r\nCache-Control: no-store\r\nConnection: close\r\nContent-Length: #{message.bytesize}\r\n\r\n#{message}"
          raise 'Authorization was declined. Run buzzsprout login to try again.' if denied
          return code if code && !code.empty?
        rescue Timeout::Error, URI::InvalidURIError, ArgumentError, IOError, SystemCallError
          # Ignore unrelated or incomplete local requests while awaiting the callback.
        ensure
          socket.close
        end
      end
    end

    def launch_browser(url)
      command = if RUBY_PLATFORM.include?('darwin')
                  ['open', url]
                elsif RUBY_PLATFORM.match?(/mswin|mingw/)
                  ['rundll32', 'url.dll,FileProtocolHandler', url]
                else
                  ['xdg-open', url]
                end
      pid = Process.spawn(*command, out: File::NULL, err: File::NULL)
      Process.detach(pid)
    rescue SystemCallError
      nil # The printed link remains available.
    end

    def revoke(data)
      uri = URI("#{data.fetch(:issuer)}/oauth/revoke")
      request = Net::HTTP::Post.new(uri)
      request['User-Agent'] = Client::USER_AGENT
      request.set_form_data(client_id: data.fetch(:client_id), token: data.fetch(:refresh_token), token_type_hint: 'refresh_token')
      response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == 'https', open_timeout: 15, read_timeout: 30) { |http| http.request(request) }
      raise 'Could not disconnect. Retry logout, or use --local-only to forget this connection on this computer.' unless response.is_a?(Net::HTTPSuccess)
    end

    def access_token
      Config.with_lock do
        Config.clear_cache
        data = Config.loaded[:oauth]
        raise 'Run buzzsprout login to connect to this server.' unless data && data[:api_base] == Config.api_base_url && data[:issuer] == issuer
        if data[:expires_at].to_i <= Time.now.to_i + 60
          updated = token_request({ grant_type: 'refresh_token', client_id: data[:client_id], refresh_token: data[:refresh_token] }, server: data[:issuer])
          data = data.merge(updated)
          Config.save(oauth: data)
        end
        data[:access_token]
      end
    end
  end
end

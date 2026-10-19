# frozen_string_literal: true

require 'uri'

module Buzzsprout
  module Redact
    PLACEHOLDER = '[REDACTED]'
    MIN_LITERAL_LENGTH = 8
    QUERY_KEYS = /\A(api_token|access_token)\z/i
    AUTH_VALUE = /Token\s+token=\S+/i
    QUERY_PAIR = /(?:api_token|access_token)=[^&\s"'\\]+/i
    JSON_SECRET_KEY = /"(api_token|access_token)"\s*:\s*"(?:\\.|[^"\\])*"/i

    module_function

    def string(text, known: nil)
      s = text.to_s.dup
      secrets(known).each do |secret|
        escaped = Regexp.escape(secret)
        s.gsub!(/Token\s+token=#{escaped}/i, "Token token=#{PLACEHOLDER}")
        s.gsub!(/(api_token|access_token)=#{escaped}/i, "\\1=#{PLACEHOLDER}")
        s.gsub!(secret, PLACEHOLDER) if secret.length >= MIN_LITERAL_LENGTH
      end
      s.gsub!(AUTH_VALUE, "Token token=#{PLACEHOLDER}")
      s.gsub!(QUERY_PAIR) { |pair| "#{pair.split('=', 2).first}=#{PLACEHOLDER}" }
      s.gsub!(JSON_SECRET_KEY, "\"\\1\": \"#{PLACEHOLDER}\"")
      s
    end

    def uri(value, known: nil)
      raw = value.is_a?(URI) ? value.dup : URI(value.to_s)
      if raw.query
        pairs = URI.decode_www_form(raw.query).map do |key, val|
          QUERY_KEYS.match?(key) ? [key, PLACEHOLDER] : [key, val]
        end
        raw.query = URI.encode_www_form(pairs)
      end
      string(raw.to_s, known: known)
    rescue URI::InvalidURIError
      string(value.to_s, known: known)
    end

    def secrets(known)
      list = []
      Array(known).each do |value|
        text = value.to_s
        list << text unless text.empty?
      end
      env = ENV['BUZZSPROUT_API_TOKEN'].to_s
      list << env unless env.empty?
      if defined?(Config)
        begin
          stored = Config.token.to_s
          list << stored unless stored.empty?
        rescue StandardError
          nil
        end
      end
      list.uniq.sort_by { |item| -item.length }
    end
  end
end

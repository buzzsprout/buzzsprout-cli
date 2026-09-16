# frozen_string_literal: true

require 'json'
require 'fileutils'

module Buzzsprout
  class Config
    DEFAULT_API_BASE = 'https://www.buzzsprout.com/api'
    DEFAULT_CONFIG_FILE = File.expand_path('~/.buzzsprout.json')

    class << self
      def config_file
        ENV['BUZZSPROUT_CONFIG'] || DEFAULT_CONFIG_FILE
      end

      def api_base_url
        (ENV['BUZZSPROUT_API_BASE'] || loaded[:api_base] || DEFAULT_API_BASE).to_s.chomp('/')
      end

      def load
        return @config if @config

        unless File.exist?(config_file)
          @config = {}
          return @config
        end

        @config = JSON.parse(File.read(config_file), symbolize_names: true)
      rescue JSON::ParserError
        raise "Could not parse #{config_file}. Fix or delete it, then run 'buzzsprout login'."
      end

      def loaded
        load
      end

      def save(config)
        merged = loaded.merge(config.transform_keys(&:to_sym))
        merged.delete_if { |_, value| value.nil? || value == '' }
        dir = File.dirname(config_file)
        FileUtils.mkdir_p(dir)
        File.write(config_file, JSON.pretty_generate(merged))
        File.chmod(0o600, config_file)
        @config = merged
      end

      def configured?
        !token.to_s.empty?
      end

      def token
        return @token if @token

        env = ENV['BUZZSPROUT_API_TOKEN']
        return @token = env unless env.to_s.empty?

        value = loaded[:api_token] || loaded[:token]
        @token = value.to_s.empty? ? nil : value
      end

      def default_podcast_id
        ENV['BUZZSPROUT_PODCAST_ID'] || loaded[:default_podcast_id] || loaded[:podcast_id]
      end

      def require_token!
        return token if configured?

        raise "Not authenticated. Run 'buzzsprout login' first (or set BUZZSPROUT_API_TOKEN)."
      end

      def clear_cache
        @config = nil
        @token = nil
      end

      def delete!
        File.delete(config_file) if File.exist?(config_file)
        clear_cache
      end
    end
  end
end

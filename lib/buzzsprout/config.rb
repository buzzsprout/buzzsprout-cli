# frozen_string_literal: true

require 'json'
require 'fileutils'
require 'tempfile'

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
        return with_lock { clear_cache; save(config) } unless Thread.current[:buzzsprout_config_locked]

        merged = loaded.merge(config.transform_keys(&:to_sym))
        merged.delete_if { |_, value| value.nil? || value == '' }
        dir = File.dirname(config_file)
        FileUtils.mkdir_p(dir)
        Tempfile.create(['buzzsprout', '.json'], dir) do |file|
          file.chmod(0o600)
          file.write(JSON.pretty_generate(merged))
          file.flush
          file.fsync
          File.rename(file.path, config_file)
        end
        @token = nil
        @config = merged
      end

      def with_lock
        FileUtils.mkdir_p(File.dirname(config_file))
        File.open("#{config_file}.lock", File::RDWR | File::CREAT, 0o600) do |lock|
          lock.flock(File::LOCK_EX)
          Thread.current[:buzzsprout_config_locked] = true
          yield
        ensure
          Thread.current[:buzzsprout_config_locked] = false
          lock.flock(File::LOCK_UN)
        end
      end

      def oauth?
        ENV['BUZZSPROUT_API_TOKEN'].to_s.empty? && loaded[:auth_method] == 'oauth'
      end

      def configured?
        oauth? ? loaded.dig(:oauth, :api_base) == api_base_url : !token.to_s.empty?
      end

      def token
        return loaded.dig(:oauth, :access_token) if oauth?
        return @token if @token

        env = ENV['BUZZSPROUT_API_TOKEN']
        return @token = env unless env.to_s.empty?

        value = loaded[:api_token] || loaded[:token]
        @token = value.to_s.empty? ? nil : value
      end

      def default_podcast_id
        ENV['BUZZSPROUT_PODCAST_ID'] || saved_podcast_id
      end

      # File-backed default only (not BUZZSPROUT_PODCAST_ID, which is per-process).
      def saved_podcast_id
        value = loaded[:default_podcast_id] || loaded[:podcast_id]
        return if value.nil? || value.to_s.empty?

        value
      end

      def require_token!
        return OAuth.access_token if oauth?
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

      private

      def chmod_private!(path)
        File.chmod(0o600, path)
      rescue NotImplementedError, SystemCallError
        nil
      end
    end
  end
end

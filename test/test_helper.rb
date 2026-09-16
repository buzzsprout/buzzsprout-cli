# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path('../lib', __dir__)

require 'minitest/autorun'
require 'stringio'
require 'json'
require 'tmpdir'
require 'fileutils'
require 'buzzsprout/cli'

module Buzzsprout
  class Test < Minitest::Test
    def setup
      @env_keys = %w[
        BUZZSPROUT_API_TOKEN BUZZSPROUT_PODCAST_ID BUZZSPROUT_CONFIG
        BUZZSPROUT_API_BASE BUZZSPROUT_NO_ANIMATION BUZZSPROUT_THEME
        BUZZSPROUT_NO_COLOR NO_COLOR COLORFGBG CI
      ]
      @saved_env = @env_keys.to_h { |key| [key, ENV[key]] }
      @env_keys.each { |key| ENV.delete(key) }
      ENV['BUZZSPROUT_NO_ANIMATION'] = '1'
      ENV['NO_COLOR'] = '1'
      ENV['CI'] = '1'
      Config.clear_cache
      Color.reset_theme!
    end

    def teardown
      Config.clear_cache
      Color.reset_theme!
      @saved_env.each do |key, value|
        if value.nil?
          ENV.delete(key)
        else
          ENV[key] = value
        end
      end
    end

    def with_config
      Dir.mktmpdir do |dir|
        path = File.join(dir, 'buzzsprout.json')
        ENV['BUZZSPROUT_CONFIG'] = path
        Config.clear_cache
        yield path
      end
    end

    def run_cli(argv, stdin_data: '')
      stdout = StringIO.new
      stderr = StringIO.new
      stdin = StringIO.new(stdin_data)
      status = CLI.new(io: stdout, err: stderr, stdin: stdin).run(argv)
      [status, stdout.string, stderr.string]
    end
  end

  class StubTransport
    attr_reader :requests

    def initialize(*responses)
      @responses = responses
      @requests = []
    end

    def request(method, uri, headers, body)
      @requests << { method: method, uri: uri, headers: headers, body: body }
      raise 'no stubbed HTTP responses left' if @responses.empty?

      @responses.shift
    end
  end

  def self.raw(status:, body: '', headers: {})
    Client::NetTransport::Raw.new(
      status: status,
      body: body.is_a?(String) ? body : JSON.generate(body),
      headers: headers.transform_keys { |key| key.to_s.downcase }
    )
  end
end

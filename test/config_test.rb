# frozen_string_literal: true

require_relative 'test_helper'

module Buzzsprout
  class ConfigTest < Test
  def test_token_from_env_overrides_file
    with_config do |path|
      File.write(path, JSON.generate(api_token: 'file-token'))
      ENV['BUZZSPROUT_API_TOKEN'] = 'env-token'
      Config.clear_cache
      assert_equal 'env-token', Config.token
    end
  end

  def test_save_writes_json_with_restricted_permissions
    with_config do |path|
      Config.save(api_token: 'secret-token', default_podcast_id: 10)
      data = JSON.parse(File.read(path), symbolize_names: true)
      assert_equal 'secret-token', data[:api_token]
      assert_equal 10, data[:default_podcast_id]
      assert_equal 0o600, File.stat(path).mode & 0o777
    end
  end

  def test_saved_podcast_id_ignores_env_override
    with_config do
      Config.save(api_token: 'secret-token', default_podcast_id: 10)
      ENV['BUZZSPROUT_PODCAST_ID'] = '99'
      Config.clear_cache
      assert_equal 10, Config.saved_podcast_id
      assert_equal '99', Config.default_podcast_id
    end
  end

  def test_require_token_without_config
    with_config do
      error = assert_raises(RuntimeError) { Config.require_token! }
      assert_match(/buzzsprout login/, error.message)
    end
  end

  def test_api_base_default
    assert_equal 'https://www.buzzsprout.com/api', Config.api_base_url
  end
end
end

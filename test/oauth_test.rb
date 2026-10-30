# frozen_string_literal: true
require_relative 'test_helper'

class OAuthTest < Buzzsprout::Test
  def credentials
    { access_token: 'private-access-token', refresh_token: 'private-refresh-token', expires_at: Time.now.to_i + 3600, client_id: 'public-client', issuer: Buzzsprout::OAuth.issuer, api_base: Buzzsprout::Config.api_base_url }
  end

  def test_browser_login_exchanges_pkce_and_validates_callback
    with_config do
      ENV['BUZZSPROUT_OAUTH_CLIENT_ID'] = 'public-client'
      callback_thread = nil
      captured = nil
      opener = lambda do |url|
        params = URI.decode_www_form(URI(url).query).to_h
        captured = params
        assert_equal 'S256', params['code_challenge_method']
        refute params.key?('resource')
        callback_thread = Thread.new do
          uri = URI(params['redirect_uri'])
          uri.query = URI.encode_www_form(code: 'one-time-code', state: 'wrong-state', iss: Buzzsprout::OAuth.issuer)
          invalid = Net::HTTP.get_response(uri)
          assert_equal '400', invalid.code
          assert_includes invalid.body.force_encoding(Encoding::UTF_8), 'That connection didn’t make it through.'
          uri.query = URI.encode_www_form(code: 'one-time-code', state: params['state'], iss: Buzzsprout::OAuth.issuer)
          response = Net::HTTP.get_response(uri)
          assert_equal '200', response.code
          assert_match %r{text/html}, response['Content-Type']
          assert_includes response.body.force_encoding(Encoding::UTF_8), 'All systems go.'
          assert_includes response.body.force_encoding(Encoding::UTF_8), 'finish connecting'
          refute_includes response.body.force_encoding(Encoding::UTF_8), 'one-time-code'
        end
      end
      exchange = lambda do |params, server:|
        assert_equal Buzzsprout::OAuth.issuer, server
        assert_equal 'one-time-code', params[:code]
        assert_equal captured['redirect_uri'], params[:redirect_uri]
        assert_equal captured['code_challenge'], [Digest::SHA256.digest(params[:code_verifier])].pack('m0').tr('+/', '-_').delete('=')
        refute params.key?(:client_secret)
        credentials
      end
      Buzzsprout::OAuth.stub(:launch_browser, opener) do
        Buzzsprout::OAuth.stub(:token_request, exchange) do
          data = Buzzsprout::OAuth.authorize(io: StringIO.new, timeout: 5)
          assert_equal 'public-client', data[:client_id]
        end
      end
      callback_thread.value
    end
  end

  def test_callback_timeout_and_denial
    server = TCPServer.new('127.0.0.1', 0)
    assert_raises(RuntimeError) { Buzzsprout::OAuth.wait_for_callback(server, state: 'state', issuer: 'https://example.com', timeout: 0) }
    thread = Thread.new do
      uri = URI("http://127.0.0.1:#{server.addr[1]}/oauth/callback")
      uri.query = URI.encode_www_form(error: 'access_denied', state: 'state', iss: 'https://example.com')
      Net::HTTP.get_response(uri)
    end
    error = assert_raises(RuntimeError) { Buzzsprout::OAuth.wait_for_callback(server, state: 'state', issuer: 'https://example.com', timeout: 5) }
    assert_match(/declined/, error.message)
    response = thread.value
    assert_includes response.body.force_encoding(Encoding::UTF_8), 'That connection didn’t make it through.'
    assert_includes response.body.force_encoding(Encoding::UTF_8), 'terminal'
  ensure
    server.close
  end

  def test_generic_callback_page_uses_app_handoff
    success = Buzzsprout::OAuth.callback_page(success: true)
    assert_includes success, "You’re all set."
    assert_includes success, 'Connection approved.<br>Return to your app to finish connecting.'
    refute_includes success, 'CLI'

    failure = Buzzsprout::OAuth.callback_page(success: false)
    assert_includes failure, 'Return to your app for details and try again.'
    refute_includes failure, 'terminal for details'
  end

  def test_refresh_persists_rotated_pair_and_reuses_it
    with_config do
      Buzzsprout::Config.save(auth_method: 'oauth', oauth: credentials.merge(expires_at: 0))
      count = 0
      exchange = lambda do |params, server:|
        count += 1
        assert_equal 'private-refresh-token', params[:refresh_token]
        { access_token: 'new-access-token', refresh_token: 'new-refresh-token', expires_at: Time.now.to_i + 3600 }
      end
      Buzzsprout::OAuth.stub(:token_request, exchange) do
        2.times { assert_equal 'new-access-token', Buzzsprout::Config.require_token! }
      end
      assert_equal 1, count
      Buzzsprout::Config.clear_cache
      assert_equal 'new-refresh-token', Buzzsprout::Config.loaded.dig(:oauth, :refresh_token)
      assert_equal 0o600, File.stat(Buzzsprout::Config.config_file).mode & 0o777
    end
  end

  def test_environment_isolation_and_explicit_api_token_override
    with_config do
      Buzzsprout::Config.save(auth_method: 'oauth', oauth: credentials)
      ENV['BUZZSPROUT_API_BASE'] = 'https://other.example.com/api'
      refute Buzzsprout::Config.configured?
      assert_raises(RuntimeError) { Buzzsprout::Config.require_token! }
      ENV['BUZZSPROUT_API_TOKEN'] = 'explicit-token'
      refute Buzzsprout::Config.oauth?
      assert_equal 'explicit-token', Buzzsprout::Config.require_token!
    end
  end

  def test_bearer_requests_and_secret_redaction
    transport = Buzzsprout::StubTransport.new(Buzzsprout.raw(status: 200, body: []))
    Buzzsprout::Client.new(token: 'private-access-token', auth_scheme: 'Bearer', transport: transport).get('/podcasts')
    assert_equal 'Bearer private-access-token', transport.requests.first[:headers]['Authorization']
    redacted = Buzzsprout::Redact.string('Bearer private-access-token {"refresh_token":"private-refresh-token"}')
    refute_includes redacted, 'private-access-token'
    refute_includes redacted, 'private-refresh-token'
  end

  def test_oauth_login_keeps_previous_credentials_on_failure
    with_config do
      Buzzsprout::Config.save(api_token: 'old-token')
      Buzzsprout::OAuth.stub(:authorize, ->(**_) { raise 'Declined' }) do
        status, = run_cli(['login'])
        assert_equal 1, status
      end
      assert_equal 'old-token', Buzzsprout::Config.token
    end
  end
  def test_failed_refresh_does_not_fall_back_to_saved_api_token
    with_config do
      Buzzsprout::Config.save(auth_method: 'oauth', oauth: credentials.merge(expires_at: 0), api_token: 'legacy-token')
      Buzzsprout::OAuth.stub(:token_request, ->(*_, **_) { raise 'Reconnect required' }) do
        assert_raises(RuntimeError) { Buzzsprout::Config.require_token! }
      end
      assert_equal 'private-refresh-token', Buzzsprout::Config.loaded.dig(:oauth, :refresh_token)
    end
  end

  def test_logout_revokes_and_forgets_and_local_only_skips_revocation
    with_config do
      Buzzsprout::Config.save(auth_method: 'oauth', oauth: credentials)
      revoked = false
      Buzzsprout::OAuth.stub(:revoke, ->(data) { revoked = true; assert_equal 'private-refresh-token', data[:refresh_token] }) do
        status, = run_cli(['logout'])
        assert_equal 0, status
      end
      assert revoked
      refute Buzzsprout::Config.configured?
      Buzzsprout::Config.save(auth_method: 'oauth', oauth: credentials)
      Buzzsprout::OAuth.stub(:revoke, ->(_) { raise 'Must not revoke' }) do
        status, = run_cli(['logout', '--local-only'])
        assert_equal 0, status
      end
      refute Buzzsprout::Config.configured?
    end
  end

  def test_refresh_is_serialized_between_processes
    skip 'fork is unavailable' unless Process.respond_to?(:fork)
    with_config do |path|
      Buzzsprout::Config.save(auth_method: 'oauth', oauth: credentials.merge(expires_at: 0))
      count_file = "#{path}.refresh-count"
      exchange = lambda do |*_, **_|
        File.open(count_file, 'a') { |f| f.puts 'refresh' }
        credentials.merge(access_token: 'rotated-access', refresh_token: 'rotated-refresh')
      end
      Buzzsprout::OAuth.stub(:token_request, exchange) do
        pids = 2.times.map do
          fork do
            begin
              exit! Buzzsprout::Config.require_token! == 'rotated-access' ? 0 : 1
            rescue StandardError
              exit! 2
            end
          end
        end
        pids.each { |pid| assert Process.wait2(pid).last.success? }
      end
      assert_equal 1, File.readlines(count_file).size
    end
  end

  def test_request_retries_once_if_another_process_rotated_its_token
    transport = Buzzsprout::StubTransport.new(
      Buzzsprout.raw(status: 401, body: {}), Buzzsprout.raw(status: 200, body: [])
    )
    tokens = ['old', 'new', 'new']
    client = Buzzsprout::Client.new(token: 'old', auth_scheme: 'Bearer', token_provider: -> { tokens.shift }, transport: transport)
    assert_equal [], client.get('/podcasts')
    assert_equal ['Bearer old', 'Bearer new'], transport.requests.map { |r| r[:headers]['Authorization'] }
  end

end

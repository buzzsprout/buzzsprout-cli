# frozen_string_literal: true

require_relative 'test_helper'

class ClientTest < Buzzsprout::Test
  def test_get_sends_token_user_agent_and_accept
    transport = Buzzsprout::StubTransport.new(
      Buzzsprout.raw(status: 200, body: [{ id: 10, title: 'Life Empowerment' }])
    )
    client = Buzzsprout::Client.new(token: 'abc123', base_url: 'https://www.buzzsprout.com/api', transport: transport)
    result = client.get('/podcasts')

    assert_equal 10, result.first['id']
    request = transport.requests.first
    assert_equal :get, request[:method]
    assert_equal '/api/podcasts', request[:uri].request_uri
    assert_equal 'Token token=abc123', request[:headers]['Authorization']
    assert_equal 'BuzzsproutCLI/0.1.0', request[:headers]['User-Agent']
    assert_equal 'application/json', request[:headers]['Accept']
  end

  def test_unauthorized
    transport = Buzzsprout::StubTransport.new(
      Buzzsprout.raw(status: 401, body: 'Invalid token')
    )
    client = Buzzsprout::Client.new(token: 'nope', transport: transport)
    error = assert_raises(Buzzsprout::Client::Unauthorized) { client.get('/podcasts') }
    assert_equal 401, error.status
    assert_match(/401/, error.message)
  end

  def test_retries_429_then_succeeds
    transport = Buzzsprout::StubTransport.new(
      Buzzsprout.raw(status: 429, body: 'slow down', headers: { 'Retry-After' => '0' }),
      Buzzsprout.raw(status: 200, body: [])
    )
    client = Buzzsprout::Client.new(token: 'abc', transport: transport)
    result = client.get('/podcasts')
    assert_equal [], result
    assert_equal 2, transport.requests.size
  end

  def test_etag_round_trip
    transport = Buzzsprout::StubTransport.new(
      Buzzsprout.raw(status: 200, body: [{ id: 1 }], headers: { 'ETag' => '"abc"' }),
      Buzzsprout.raw(status: 304, body: '', headers: { 'ETag' => '"abc"' })
    )
    client = Buzzsprout::Client.new(token: 'abc', transport: transport)
    first = client.get('/podcasts', use_etag: true)
    second = client.get('/podcasts', use_etag: true)
    assert_equal first, second
    assert_equal '"abc"', transport.requests.last[:headers]['If-None-Match']
  end

  def test_structured_error
    transport = Buzzsprout::StubTransport.new(
      Buzzsprout.raw(status: 422, body: { error: { code: 'invalid', message: 'Title can\'t be blank', param: 'title' } })
    )
    client = Buzzsprout::Client.new(token: 'abc', transport: transport)
    error = assert_raises(Buzzsprout::Client::Error) { client.post('/10/episodes', body: {}) }
    assert_match(/Title/, error.message)
    assert_equal 'invalid', error.error_code
    assert_equal 'title', error.param
  end

  def test_dry_run_does_not_call_transport
    transport = Buzzsprout::StubTransport.new
    io = StringIO.new
    client = Buzzsprout::Client.new(token: 'abc', transport: transport, dry_run: true, io: io)
    assert_nil client.get('/podcasts')
    assert_empty transport.requests
    assert_match(/dry-run/, io.string)
    refute_match(/abc/, io.string)
  end

  def test_put_bytes_omits_authorization
    transport = Buzzsprout::StubTransport.new(Buzzsprout.raw(status: 200, body: ''))
    client = Buzzsprout::Client.new(token: 'secret', transport: transport)
    client.put_bytes('https://uploads.example.com/x', 'bytes')
    headers = transport.requests.first[:headers]
    refute headers.key?('Authorization')
    assert_equal 'BuzzsproutCLI/0.1.0', headers['User-Agent']
  end
end

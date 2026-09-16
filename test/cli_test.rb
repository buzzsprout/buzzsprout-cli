# frozen_string_literal: true

require 'socket'
require_relative 'test_helper'

class FakeApi
  attr_reader :requests, :base

  def initialize(responses)
    @requests = []
    @responses = responses
    @server = TCPServer.new('127.0.0.1', 0)
    @port = @server.addr[1]
    @base = "http://127.0.0.1:#{@port}/api"
    @running = true
    @thread = Thread.new { accept_loop }
    @thread.report_on_exception = true
  end

  def shutdown
    @running = false
    @server.close unless @server.closed?
    @thread.join(0.5)
    @thread.kill if @thread.alive?
  end

  private

  def accept_loop
    while @running
      client = @server.accept
      handle(client)
    end
  rescue IOError, Errno::EBADF, Errno::EINVAL
    nil
  end

  def handle(socket)
    request_line = socket.gets
    return unless request_line

    method, raw_path, = request_line.split
    path = raw_path.to_s.split('?', 2).first
    headers = {}
    loop do
      line = socket.gets
      break if line.nil? || line == "\r\n" || line == "\n"

      key, value = line.split(':', 2)
      headers[key.to_s.downcase] = value.to_s.strip
    end
    length = headers['content-length'].to_i
    body = length.positive? ? socket.read(length) : nil

    @requests << {
      method: method,
      path: path,
      authorization: headers['authorization'],
      user_agent: headers['user-agent'],
      accept: headers['accept'],
      content_type: headers['content-type'],
      body: body
    }

    spec = @responses[[method, path]] || @responses[path] || @responses[:default] || { status: 404, body: 'not found' }
    payload = spec[:body].is_a?(String) ? spec[:body] : JSON.generate(spec[:body] || {})
    status = spec[:status] || 200
    socket.write "HTTP/1.1 #{status} OK\r\n"
    socket.write "Content-Type: #{spec[:content_type] || 'application/json'}\r\n"
    socket.write "Content-Length: #{payload.bytesize}\r\n"
    socket.write "Connection: close\r\n\r\n"
    socket.write payload
  ensure
    socket.close
  end
end

class CLITest < Buzzsprout::Test
  def test_help_and_version
      status, out, = run_cli(['--help'])
    assert_equal 0, status
    assert_match(/login, auth, init/, out)

    status, out, = run_cli(['version'])
    assert_equal 0, status
    assert_match(/0\.1\.0/, out)
  end

  def test_unknown_command
    status, out, err = run_cli(['nope'])
    assert_equal 1, status
    assert_match(/Unknown command/, err)
    assert_match(/Usage/, out)
  end

  def test_login_success_persists_token_and_celebrates
    with_config do |path|
      api = FakeApi.new(
        '/api/podcasts' => {
          status: 200,
          body: [
            { id: 10, title: 'Life Empowerment', author: 'Motivational Mike', rss_url: 'https://feeds.buzzsprout.com/10.rss' },
            { id: 20, title: 'Youth Podcast' }
          ]
        }
      )
      ENV['BUZZSPROUT_API_BASE'] = api.base
      begin
        status, out, err = run_cli(['login', '--no-animation'], stdin_data: "super-secret-token\n")
        assert_equal 0, status, err
        assert_match(/You're in/, out)
        assert_match(/Life Empowerment/, out)
        assert_match(/Youth Podcast/, out)
        refute_match(/super-secret-token/, out)
        refute_match(/\e\[0J/, out, 'confetti must skip with --no-animation')

        request = api.requests.first
        assert_equal 'GET', request[:method]
        assert_equal '/api/podcasts', request[:path]
        assert_equal 'Token token=super-secret-token', request[:authorization]
        assert_equal 'BuzzsproutCLI/0.1.0', request[:user_agent]
        assert_equal 'application/json', request[:accept]

        saved = JSON.parse(File.read(path), symbolize_names: true)
        assert_equal 'super-secret-token', saved[:api_token]
      ensure
        api.shutdown
      end
    end
  end

  def test_login_failure_without_tty_does_not_save
    with_config do |path|
      api = FakeApi.new('/api/podcasts' => { status: 401, body: 'Invalid token' })
      ENV['BUZZSPROUT_API_BASE'] = api.base
      begin
        status, out, err = run_cli(['login', '--no-animation', '--token', 'bad'], stdin_data: '')
        assert_equal 1, status
        assert_match(/401/, err)
        refute_match(/You're in/, out)
        refute_path_exists path
      ensure
        api.shutdown
      end
    end
  end

  def test_podcasts_list_and_show
    with_config do
      Buzzsprout::Config.save(api_token: 'ok')
      api = FakeApi.new(
        '/api/podcasts' => { status: 200, body: [{ id: 10, title: 'Life Empowerment', author: 'Mike' }] },
        '/api/podcasts/10' => { status: 200, body: { id: 10, title: 'Life Empowerment', rss_url: 'https://feeds.buzzsprout.com/10.rss' } }
      )
      ENV['BUZZSPROUT_API_BASE'] = api.base
      begin
        status, out, err = run_cli(['podcasts', '--json'])
        assert_equal 0, status, err
        assert_match(/Life Empowerment/, out)

        status, out, err = run_cli(['podcasts', 'show', '10', '--json'])
        assert_equal 0, status, err
        assert_match(/feeds\.buzzsprout/, out)
      ensure
        api.shutdown
      end
    end
  end

  def test_episodes_list
    with_config do
      Buzzsprout::Config.save(api_token: 'ok')
      api = FakeApi.new(
        '/api/10/episodes' => { status: 200, body: [{ id: 7, title: 'Pilot', private: true, total_plays: 0 }] }
      )
      ENV['BUZZSPROUT_API_BASE'] = api.base
      begin
        status, out, err = run_cli(['episodes', 'list', '10'])
        assert_equal 0, status, err
        assert_match(/Pilot/, out)
        assert_match(/private/, out)
      ensure
        api.shutdown
      end
    end
  end

  def test_dry_run_create_episode
    with_config do
      Buzzsprout::Config.save(api_token: 'ok')
      status, _, err = run_cli(['episodes', 'create', '10', '--title', 'Hello', '--private', '--dry-run'])
      assert_equal 0, status, err
      assert_match(/dry-run/, err)
      assert_match(/POST/, err)
      assert_match(/Token token=\[REDACTED\]/, err)
      refute_match(/token=ok/, err)
    end
  end

  def test_unauthenticated_command
    with_config do
      status, _, err = run_cli(['podcasts'])
      assert_equal 1, status
      assert_match(/Not authenticated/, err)
    end
  end

  def test_skills_path_and_list
    status, out, err = run_cli(['skills', 'path'])
    assert_equal 0, status, err
    assert File.directory?(out.strip)
    assert File.file?(File.join(out.strip, 'podcasts', 'SKILL.md'))

    status, out, = run_cli(['skills'])
    assert_equal 0, status
    %w[podcasts episodes uploads stats team contributors brand_affiliations chapters transcripts listings podrolls feed_verifications fan_mail insertion_points soundbites buzzsprout].each do |name|
      assert_match(/#{name}/, out)
    end
  end
end

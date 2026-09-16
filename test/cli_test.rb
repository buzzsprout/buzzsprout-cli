# frozen_string_literal: true

require 'socket'
require 'date'
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
    path, query = raw_path.to_s.split('?', 2)
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
      query: query,
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
    assert_match(/podcast use/, out)
    assert_match(/episode <id> downloads today\|yesterday\|YYYY-MM-DD/, out)
    assert_match(/downloads today\|yesterday\|YYYY-MM-DD/, out)
    refute_match(/^        use \[/, out)

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

  def test_downloads_without_date_prints_group_help
    status, out, err = run_cli(['downloads'])
    assert_equal 0, status, err
    assert_match(/USAGE/, out)
    assert_match(/episode <id> downloads today\|yesterday\|YYYY-MM-DD/, out)
    assert_match(/downloads today\|yesterday\|YYYY-MM-DD/, out)
    refute_match(/Error:/, err)
    refute_match(/Downloads for/, out)
  end

  def test_downloads_help_flag_prints_group_help
    status, out, err = run_cli(['downloads', '--help'])
    assert_equal 0, status, err
    assert_match(/USAGE/, out)
    assert_match(/episode <id> downloads/, out)
    refute_match(/Error:/, err)
  end

  def test_downloads_today_keyword
    with_config do
      Buzzsprout::Config.save(api_token: 'ok', default_podcast_id: 10)
      today = Date.today.strftime('%Y-%m-%d')
      api = FakeApi.new(
        '/api/10/downloads' => { status: 200, body: [{ episode_id: 7, total: 2 }] }
      )
      ENV['BUZZSPROUT_API_BASE'] = api.base
      begin
        status, out, err = run_cli(['downloads', 'today'])
        assert_equal 0, status, err
        assert_match(/Downloads for #{today}/, out)
        req = api.requests.find { |row| row[:path] == '/api/10/downloads' }
        refute_nil req
        assert_includes req[:query].to_s, "date=#{today}"
      ensure
        api.shutdown
      end
    end
  end

  def test_downloads_yesterday_keyword_is_case_insensitive
    with_config do
      Buzzsprout::Config.save(api_token: 'ok', default_podcast_id: 10)
      yesterday = (Date.today - 1).strftime('%Y-%m-%d')
      api = FakeApi.new(
        '/api/10/downloads' => { status: 200, body: [{ episode_id: 7, total: 1 }] }
      )
      ENV['BUZZSPROUT_API_BASE'] = api.base
      begin
        status, out, err = run_cli(['downloads', 'Yesterday'])
        assert_equal 0, status, err
        assert_match(/Downloads for #{yesterday}/, out)
        req = api.requests.find { |row| row[:path] == '/api/10/downloads' }
        refute_nil req
        assert_includes req[:query].to_s, "date=#{yesterday}"
      ensure
        api.shutdown
      end
    end
  end

  def test_downloads_explicit_date_and_stats_alias
    with_config do
      Buzzsprout::Config.save(api_token: 'ok', default_podcast_id: 10)
      api = FakeApi.new(
        '/api/10/downloads' => { status: 200, body: [{ episode_id: 7, total: 4 }] }
      )
      ENV['BUZZSPROUT_API_BASE'] = api.base
      begin
        status, out, err = run_cli(['downloads', '2026-09-01'])
        assert_equal 0, status, err
        assert_match(/Downloads for 2026-09-01/, out)
        req = api.requests.find { |row| row[:path] == '/api/10/downloads' }
        refute_nil req
        assert_includes req[:query].to_s, 'date=2026-09-01'

        status, out, err = run_cli(['stats', '--date', '2026-09-01'])
        assert_equal 0, status, err
        assert_match(/Downloads for 2026-09-01/, out)
      ensure
        api.shutdown
      end
    end
  end

  def test_episode_downloads_today_yesterday_and_iso_date
    with_config do
      Buzzsprout::Config.save(api_token: 'ok', default_podcast_id: 10)
      today = Date.today.strftime('%Y-%m-%d')
      yesterday = (Date.today - 1).strftime('%Y-%m-%d')
      api = FakeApi.new(
        '/api/10/788881/downloads' => {
          status: 200,
          body: { episodes: [{ downloads: [{ app: 'Apple Podcasts', country_code: 'US' }] }] }
        }
      )
      ENV['BUZZSPROUT_API_BASE'] = api.base
      begin
        status, out, err = run_cli(['episode', '788881', 'downloads', 'today'])
        assert_equal 0, status, err
        assert_match(/Episode 788881 downloads for #{today}/, out)
        assert_match(/Apple Podcasts/, out)
        req = api.requests.find { |row| row[:path] == '/api/10/788881/downloads' }
        refute_nil req
        assert_includes req[:query].to_s, "date=#{today}"

        status, out, err = run_cli(['episode', '788881', 'downloads', 'yesterday'])
        assert_equal 0, status, err
        assert_match(/Episode 788881 downloads for #{yesterday}/, out)

        status, out, err = run_cli(['episode', '788881', 'downloads', '2026-09-01'])
        assert_equal 0, status, err
        assert_match(/Episode 788881 downloads for 2026-09-01/, out)
        req = api.requests.reverse.find { |row| row[:path] == '/api/10/788881/downloads' }
        assert_includes req[:query].to_s, 'date=2026-09-01'
      ensure
        api.shutdown
      end
    end
  end

  def test_episode_downloads_without_id_prints_group_help
    with_config do
      Buzzsprout::Config.save(api_token: 'ok', default_podcast_id: 10)
      api = FakeApi.new(
        '/api/10/downloads' => { status: 200, body: [{ episode_id: 7, total: 2 }] }
      )
      ENV['BUZZSPROUT_API_BASE'] = api.base
      begin
        status, out, err = run_cli(['episode', 'downloads', 'yesterday'])
        assert_equal 0, status, err
        assert_match(/USAGE/, out)
        assert_match(/episode <id> downloads/, out)
        refute_match(/Error:/, err)
        refute_match(/Downloads for/, out)
        refute api.requests.any? { |row| row[:path].to_s.include?('/downloads') }
      ensure
        api.shutdown
      end
    end
  end

  def test_episode_downloads_without_date_prints_group_help
    status, out, err = run_cli(['episode', '788881', 'downloads'])
    assert_equal 0, status, err
    assert_match(/USAGE/, out)
    refute_match(/Error:/, err)
  end

  def test_uploads_without_args_prints_group_help
    status, out, err = run_cli(['uploads'])
    assert_equal 0, status, err
    assert_match(/USAGE/, out)
    assert_match(/start/, out)
    refute_match(/Error:/, err)
  end

  def test_chapters_without_args_prints_group_help
    status, out, err = run_cli(['chapters'])
    assert_equal 0, status, err
    assert_match(/USAGE/, out)
    assert_match(/replace/, out)
    refute_match(/Error:/, err)
  end

  def test_unknown_subcommand_prints_group_help
    status, out, err = run_cli(['episodes', 'nope'])
    assert_equal 0, status, err
    assert_match(/USAGE/, out)
    assert_match(/COMMANDS/, out)
    refute_match(/Error:/, err)
  end

  def test_podcasts_help_flag_does_not_require_auth
    status, out, err = run_cli(['podcasts', '--help'])
    assert_equal 0, status, err
    assert_match(/podcast use/, out)
    refute_match(/Not authenticated/, err)
  end

  def test_top_level_use_is_unknown
    status, _, err = run_cli(['use', '10'])
    assert_equal 1, status
    assert_match(/Unknown command: use/, err)
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
        assert_match(/\n\nAuthentication Successful\n/, out)
        assert_match(/Life Empowerment/, out)
        assert_match(/Youth Podcast/, out)
        refute_match(/super-secret-token/, out)
        refute_match(/You're in/, out)
        refute_match(/authentication successful!/i, out)

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

  def test_login_success_message_without_no_animation_flag
    ENV.delete('BUZZSPROUT_NO_ANIMATION')
    ENV.delete('CI')
    with_config do
      api = FakeApi.new(
        '/api/podcasts' => { status: 200, body: [{ id: 10, title: 'Life Empowerment' }] }
      )
      ENV['BUZZSPROUT_API_BASE'] = api.base
      begin
        status, out, err = run_cli(['login', '--token', 'ok'])
        assert_equal 0, status, err
        assert_match(/\n\nAuthentication Successful\n/, out)
        refute_match(/You're in/, out)
        refute_match(/\e\[0J/, out)
      ensure
        api.shutdown
      end
    end
  end

  def test_login_success_message_uses_logo_green
    ENV.delete('NO_COLOR')
    ENV.delete('BUZZSPROUT_NO_COLOR')
    with_config do
      io = Buzzsprout::FakeTty.new
      err = StringIO.new
      command = Buzzsprout::Commands::Login.new(
        [],
        Buzzsprout::Options.new,
        io: io,
        err: err,
        stdin: StringIO.new
      )
      command.send(:celebrate, [{ 'id' => 10, 'title' => 'Life Empowerment' }])
      out = io.string
      assert_match(/\A\n/, out)
      assert_includes out, 'Authentication Successful'
      assert_includes out, '38;2;97;215;82'
      refute_includes out, "\e[32m"
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
        refute_match(/Authentication Successful/, out)
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
        status, out, err = run_cli(['podcasts'])
        assert_equal 0, status, err
        assert_match(/Life Empowerment - #10/, out)
        refute_match(/Mike/, out)
        refute_match(/\d+\s{2}Life Empowerment/, out)

        status, out, err = run_cli(['podcasts', '--json'])
        assert_equal 0, status, err
        assert_match(/Life Empowerment/, out)
        assert_match(/Mike/, out)

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
        refute api.requests.any? { |req| req[:path] == '/api/podcasts' }
      ensure
        api.shutdown
      end
    end
  end

  def test_episodes_list_podcast_flag_and_in_alias_skip_picker
    with_config do
      Buzzsprout::Config.save(api_token: 'ok')
      api = FakeApi.new(
        '/api/10/episodes' => { status: 200, body: [{ id: 7, title: 'Pilot', private: true, total_plays: 0 }] },
        '/api/20/episodes' => { status: 200, body: [{ id: 8, title: 'Youth ep', private: false, total_plays: 3 }] }
      )
      ENV['BUZZSPROUT_API_BASE'] = api.base
      begin
        status, out, err = run_cli(['episodes', 'list', '--podcast', '10'], tty: true, stdin_data: "\r")
        assert_equal 0, status, err
        assert_match(/Pilot/, out)
        refute_match(/Select a podcast/, out)

        status, out, err = run_cli(['episodes', 'list', '--in', '20'], tty: true, stdin_data: "\r")
        assert_equal 0, status, err
        assert_match(/Youth ep/, out)
        refute_match(/Select a podcast/, out)
        refute api.requests.any? { |req| req[:path] == '/api/podcasts' }
      ensure
        api.shutdown
      end
    end
  end

  def test_episodes_list_without_id_on_tty_opens_picker_and_saves
    with_config do |path|
      Buzzsprout::Config.save(api_token: 'ok')
      api = FakeApi.new(
        '/api/podcasts' => {
          status: 200,
          body: [
            { id: 10, title: 'Life Empowerment' },
            { id: 20, title: 'Youth Podcast' }
          ]
        },
        '/api/20/episodes' => { status: 200, body: [{ id: 8, title: 'Youth ep', private: false, total_plays: 1 }] }
      )
      ENV['BUZZSPROUT_API_BASE'] = api.base
      begin
        status, out, err = run_cli(['episodes', 'list'], tty: true, stdin_data: "\e[B\r")
        assert_equal 0, status, err
        assert_match(/Select a podcast/, out)
        assert_match(/Search:/, out)
        assert_match(/Youth ep/, out)
        assert_match(/Using podcast 20/, out)
        assert api.requests.any? { |req| req[:path] == '/api/podcasts' }
        assert api.requests.any? { |req| req[:path] == '/api/20/episodes' }
        saved = JSON.parse(File.read(path), symbolize_names: true)
        assert_equal 20, saved[:default_podcast_id]
      ensure
        api.shutdown
      end
    end
  end

  def test_episodes_list_reuses_saved_podcast_without_picker
    with_config do
      Buzzsprout::Config.save(api_token: 'ok', default_podcast_id: 10)
      api = FakeApi.new(
        '/api/10/episodes' => { status: 200, body: [{ id: 7, title: 'Pilot', private: true, total_plays: 0 }] }
      )
      ENV['BUZZSPROUT_API_BASE'] = api.base
      begin
        status, out, err = run_cli(['episodes', 'list'], tty: true, stdin_data: "\e[B\r")
        assert_equal 0, status, err
        assert_match(/Pilot/, out)
        refute_match(/Select a podcast/, out)
        refute api.requests.any? { |req| req[:path] == '/api/podcasts' }
        assert api.requests.any? { |req| req[:path] == '/api/10/episodes' }
      ensure
        api.shutdown
      end
    end
  end

  def test_episodes_list_persists_picker_choice_for_later_commands
    with_config do |path|
      Buzzsprout::Config.save(api_token: 'ok')
      api = FakeApi.new(
        '/api/podcasts' => {
          status: 200,
          body: [
            { id: 10, title: 'Life Empowerment' },
            { id: 20, title: 'Youth Podcast' }
          ]
        },
        '/api/20/episodes' => { status: 200, body: [{ id: 8, title: 'Youth ep', private: false, total_plays: 1 }] }
      )
      ENV['BUZZSPROUT_API_BASE'] = api.base
      begin
        status, out, err = run_cli(['episodes', 'list'], tty: true, stdin_data: "youth\r")
        assert_equal 0, status, err
        assert_match(/Select a podcast/, out)
        assert_equal 20, JSON.parse(File.read(path), symbolize_names: true)[:default_podcast_id]

        status, out, err = run_cli(['episodes', 'list'], tty: true, stdin_data: "\r")
        assert_equal 0, status, err
        refute_match(/Select a podcast/, out)
        assert_match(/Youth ep/, out)
        assert_equal 1, api.requests.count { |req| req[:path] == '/api/podcasts' }
        assert_equal 2, api.requests.count { |req| req[:path] == '/api/20/episodes' }
      ensure
        api.shutdown
      end
    end
  end

  def test_episodes_list_filter_selects_on_tty
    with_config do |path|
      Buzzsprout::Config.save(api_token: 'ok')
      api = FakeApi.new(
        '/api/podcasts' => {
          status: 200,
          body: [
            { id: 10, title: 'Life Empowerment' },
            { id: 20, title: 'Youth Podcast' }
          ]
        },
        '/api/20/episodes' => { status: 200, body: [{ id: 8, title: 'Youth ep', private: false, total_plays: 1 }] }
      )
      ENV['BUZZSPROUT_API_BASE'] = api.base
      begin
        status, out, err = run_cli(['episodes', 'list'], tty: true, stdin_data: "youth\r")
        assert_equal 0, status, err
        assert_match(/Youth ep/, out)
        saved = JSON.parse(File.read(path), symbolize_names: true)
        assert_equal 20, saved[:default_podcast_id]
      ensure
        api.shutdown
      end
    end
  end

  def test_episodes_list_without_id_noninteractive_errors
    with_config do
      Buzzsprout::Config.save(api_token: 'ok')
      status, _, err = run_cli(['episodes', 'list'])
      assert_equal 1, status
      assert_match(/Pass --podcast ID/, err)
      assert_match(/buzzsprout podcast use/, err)
    end
  end

  def test_json_uses_saved_default_and_never_opens_picker
    with_config do
      Buzzsprout::Config.save(api_token: 'ok', default_podcast_id: 10)
      api = FakeApi.new(
        '/api/10/episodes' => { status: 200, body: [{ id: 7, title: 'Pilot', private: true, total_plays: 0 }] }
      )
      ENV['BUZZSPROUT_API_BASE'] = api.base
      begin
        status, out, err = run_cli(['episodes', 'list', '--json'], tty: true, stdin_data: "\r")
        assert_equal 0, status, err
        assert_match(/Pilot/, out)
        refute_match(/Select a podcast/, out)
        refute api.requests.any? { |req| req[:path] == '/api/podcasts' }
      ensure
        api.shutdown
      end
    end
  end

  def test_noninteractive_env_never_opens_picker
    with_config do
      Buzzsprout::Config.save(api_token: 'ok')
      ENV['BUZZSPROUT_NONINTERACTIVE'] = '1'
      status, out, err = run_cli(['episodes', 'list'], tty: true, stdin_data: "\r")
      assert_equal 1, status
      assert_match(/Pass --podcast ID/, err)
      refute_match(/Select a podcast/, out)
    end
  end

  def test_use_without_args_picks_and_saves
    with_config do |path|
      Buzzsprout::Config.save(api_token: 'ok', default_podcast_id: 10)
      api = FakeApi.new(
        '/api/podcasts' => {
          status: 200,
          body: [
            { id: 10, title: 'Life Empowerment' },
            { id: 20, title: 'Youth Podcast' }
          ]
        }
      )
      ENV['BUZZSPROUT_API_BASE'] = api.base
      begin
        status, out, err = run_cli(['podcast', 'use'], tty: true, stdin_data: "\e[B\r")
        assert_equal 0, status, err
        assert_match(/Select a podcast/, out)
        assert_match(/Default podcast set to 20/, out)
        saved = JSON.parse(File.read(path), symbolize_names: true)
        assert_equal 20, saved[:default_podcast_id]
      ensure
        api.shutdown
      end
    end
  end

  def test_use_with_id_skips_picker
    with_config do |path|
      Buzzsprout::Config.save(api_token: 'ok')
      status, out, err = run_cli(['podcast', 'use', '10'], tty: true, stdin_data: "\r")
      assert_equal 0, status, err
      assert_match(/Default podcast set to 10/, out)
      refute_match(/Select a podcast/, out)
      saved = JSON.parse(File.read(path), symbolize_names: true)
      assert_equal '10', saved[:default_podcast_id].to_s
    end
  end

  def test_picker_cancel_exits_cleanly
    with_config do
      Buzzsprout::Config.save(api_token: 'ok')
      api = FakeApi.new(
        '/api/podcasts' => {
          status: 200,
          body: [
            { id: 10, title: 'Life Empowerment' },
            { id: 20, title: 'Youth Podcast' }
          ]
        }
      )
      ENV['BUZZSPROUT_API_BASE'] = api.base
      begin
        status, out, err = run_cli(['episodes', 'list'], tty: true, stdin_data: "\e")
        assert_equal 1, status
        assert_match(/cancelled/, err)
        refute_match(/Error:/, err)
        refute_match(/Pilot/, out)
      ensure
        api.shutdown
      end
    end
  end

  def test_login_tty_picks_default_after_success
    with_config do |path|
      api = FakeApi.new(
        '/api/podcasts' => {
          status: 200,
          body: [
            { id: 10, title: 'Life Empowerment' },
            { id: 20, title: 'Youth Podcast' }
          ]
        }
      )
      ENV['BUZZSPROUT_API_BASE'] = api.base
      begin
        status, out, err = run_cli(['login', '--no-animation'], tty: true, stdin_data: "super-secret-token\n\e[B\r")
        assert_equal 0, status, err
        assert_match(/\n\nAuthentication Successful\n/, out)
        assert_match(/Select a podcast/, out)
        assert_match(/Default podcast set to 20/, out)
        saved = JSON.parse(File.read(path), symbolize_names: true)
        assert_equal 'super-secret-token', saved[:api_token]
        assert_equal 20, saved[:default_podcast_id]
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

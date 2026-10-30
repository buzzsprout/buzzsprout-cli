# frozen_string_literal: true

require_relative 'test_helper'

class UpdaterTest < Buzzsprout::Test
  def with_installation
    Dir.mktmpdir do |dir|
      source = File.join(dir, 'source.git')
      installed = File.join(dir, 'installed')
      FileUtils.mkdir_p(File.join(source, 'bin'))
      git(source, 'init', '-b', 'main')
      git(source, 'config', 'user.name', 'Test')
      git(source, 'config', 'user.email', 'test@example.com')
      File.write(File.join(source, 'bin/buzzsprout'), "puts 'old skills'\n")
      git(source, 'add', '.')
      git(source, 'commit', '-m', 'Initial')
      git(dir, 'clone', source, installed)
      # Stand in for the GitHub commits API with the local source repository.
      updater = Class.new(Buzzsprout::Updater) do
        def latest_commit
          git('ls-remote', @repository, 'refs/heads/main').split("\t").first
        end
      end.new(root: installed, repository: source)
      yield updater, source, installed
    end
  end

  def git(root, *args)
    out, err, result = Open3.capture3('git', '-C', root, *args)
    assert result.success?, err
    out.strip
  end

  def advance(source)
    File.write(File.join(source, 'bin/buzzsprout'), "puts 'new skills'\n")
    git(source, 'add', '.')
    git(source, 'commit', '-m', 'New CLI and skills')
    git(source, 'rev-parse', 'HEAD')
  end

  def test_updates_to_main_and_runs_new_skill_installer
    with_installation do |updater, source, installed|
      target = advance(source)
      out = StringIO.new
      result = updater.update(io: out, dir: @skills_dir)
      assert result[:updated]
      assert result[:skills_refreshed]
      assert_equal target, git(installed, 'rev-parse', 'HEAD')
      assert_includes out.string, 'new skills'
      refute_includes out.string, 'old skills'
      refute updater.update(io: StringIO.new, dir: @skills_dir)[:updated]
    end
  end

  def test_refuses_dirty_checkout_and_development_branch
    with_installation do |updater, _source, installed|
      File.write(File.join(installed, 'untracked'), 'keep me')
      assert_match(/Local changes/, assert_raises(RuntimeError) { updater.update(io: StringIO.new) }.message)
      assert_equal 'keep me', File.read(File.join(installed, 'untracked'))
      File.delete(File.join(installed, 'untracked'))
      git(installed, 'checkout', '-b', 'feature-test')
      assert_match(/main branch/, assert_raises(RuntimeError) { updater.check }.message)
    end
  end

  def test_refuses_rewritten_fetch_url
    with_installation do |updater, source, installed|
      # Origin keeps an accepted spelling while the fetch URL alone is rewritten.
      git(installed, 'remote', 'set-url', 'origin', source.delete_suffix('.git'))
      git(installed, 'config', "url.#{File.join(installed, 'decoy')}.insteadOf", source)
      assert_match(/insteadOf/, assert_raises(RuntimeError) { updater.validate! }.message)
    end
  end

  def test_refuses_fetched_commit_that_does_not_match_published_main
    with_installation do |updater, source, installed|
      before = git(installed, 'rev-parse', 'HEAD')
      advance(source)
      updater.stub(:latest_commit, '0' * 40) do
        assert_match(/does not match/, assert_raises(RuntimeError) { updater.update(io: StringIO.new) }.message)
      end
      assert_equal before, git(installed, 'rev-parse', 'HEAD')
    end
  end

  def test_refuses_unrelated_repository
    with_installation do |_updater, _source, installed|
      git(installed, 'remote', 'set-url', 'origin', 'https://example.com/other.git')
      updater = Buzzsprout::Updater.new(root: installed)
      assert_match(/official/, assert_raises(RuntimeError) { updater.validate! }.message)
    end
  end

  def test_refuses_local_commits_without_resetting_them
    with_installation do |updater, source, installed|
      git(installed, 'config', 'user.name', 'Test')
      git(installed, 'config', 'user.email', 'test@example.com')
      File.write(File.join(installed, 'local'), 'keep me')
      git(installed, 'add', '.')
      git(installed, 'commit', '-m', 'Local changes')
      before = git(installed, 'rev-parse', 'HEAD')
      advance(source)
      assert_raises(RuntimeError) { updater.update(io: StringIO.new) }
      assert_equal before, git(installed, 'rev-parse', 'HEAD')
      assert_equal 'keep me', File.read(File.join(installed, 'local'))
    end
  end

  def test_check_and_daily_notifications_do_not_change_checkout
    with_config do
      with_installation do |updater, source, installed|
        ENV.delete('CI')
        before = git(installed, 'rev-parse', 'HEAD')
        target = advance(source)
        calls = 0
        updater.stub(:latest_commit, -> { calls += 1; target }) do
          assert updater.check[:update_available]
          2.times do
            output = StringIO.new
            updater.notify(io: output)
            assert_includes output.string, 'buzzsprout update'
          end
        end
        assert_equal 2, calls # One explicit check, one cached automatic check.
        assert_equal before, git(installed, 'rev-parse', 'HEAD')
      end
    end
  end

  def test_offline_checks_are_silent_and_cached_and_can_be_disabled
    with_config do
      with_installation do |updater, _source, _installed|
        ENV.delete('CI')
        calls = 0
        updater.stub(:latest_commit, -> { calls += 1; raise 'offline' }) do
          output = StringIO.new
          2.times { updater.notify(io: output) }
          assert_empty output.string
          assert_equal 1, calls
          ENV['BUZZSPROUT_NO_UPDATE_CHECK'] = '1'
          updater.notify(io: output)
          assert_equal 1, calls
        end
      end
    end
  end

  def test_json_check_preserves_stdout_and_never_updates
    updater = Object.new
    def updater.check
      { update_available: true, update_command: 'buzzsprout update' }
    end
    Buzzsprout::Updater.stub(:new, updater) do
      status, out, err = run_cli(['update', '--check', '--json'])
      assert_equal 0, status, err
      assert_equal true, JSON.parse(out)['update_available']
      assert_empty err
    end
  end

  def test_skill_failure_reports_partial_update
    with_installation do |updater, source, installed|
      File.write(File.join(source, 'bin/buzzsprout'), "warn 'skill conflict'; exit 1\n")
      git(source, 'add', '.')
      git(source, 'commit', '-m', 'Failing skill refresh')
      target = git(source, 'rev-parse', 'HEAD')
      error = assert_raises(RuntimeError) { updater.update(io: StringIO.new, dir: @skills_dir) }
      assert_match(/CLI updated, but skills/, error.message)
      assert_equal target, git(installed, 'rev-parse', 'HEAD')
    end
  end

  def test_executable_returns_command_failure_status
    _out, err, status = Open3.capture3(RbConfig.ruby, File.expand_path('../bin/buzzsprout', __dir__), 'unknown-command')
    assert_equal 1, status.exitstatus
    assert_includes err, 'Unknown command'
  end
end

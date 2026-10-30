# frozen_string_literal: true

require 'open3'
require_relative 'test_helper'

class InstallTest < Buzzsprout::Test
  def script
    File.expand_path('../script/install', __dir__)
  end

  def repo_root
    File.expand_path('..', __dir__)
  end

  def test_readme_documents_public_repo_install_and_updates
    readme = File.read(File.expand_path('../README.md', __dir__))
    assert_includes readme, 'git clone https://github.com/buzzsprout/buzzsprout-cli.git ~/.buzzsprout-cli'
    assert_includes readme, '~/.buzzsprout-cli/script/install'
    assert_includes readme, 'buzzsprout login'
    assert_includes readme, 'buzzsprout update --check --json'
    assert_includes readme, 'no GitHub account is required'
    curl_idx = readme.index('curl -fsSL https://raw.githubusercontent.com/buzzsprout/buzzsprout-cli/main/script/install | bash')
    clone_idx = readme.index('git clone https://github.com/buzzsprout/buzzsprout-cli.git ~/.buzzsprout-cli')
    refute_nil curl_idx
    refute_nil clone_idx
    assert_operator curl_idx, :<, clone_idx
  end

  def test_install_script_is_self_contained
    text = File.read(script)
    assert_match(%r{\A#!/usr/bin/env bash}, text)
    assert_includes text, 'Ruby 3.0'
    assert_includes text, 'BUZZSPROUT_CLI_REF'
    assert_includes text, 'ln -sfn'
    refute_match(/curl .*\| *bash/, text.split("\n").grep_v(/^\s*#/).join("\n"))
  end

  def test_installer_recognizes_existing_legacy_remote
    definitions = File.read(script).split('BIN_DIR="$(pick_bin_dir)"').first
    %w[https://github.com/higher-pixels/buzzsprout-cli.git git@github.com:higher-pixels/buzzsprout-cli.git https://github.com/buzzsprout/buzzsprout-cli.git].each do |remote|
      out, err, status = Open3.capture3('bash', '-c', definitions + "\nnormalize_git_url \"$1\"\n", 'test', remote)
      assert status.success?, err
      assert_equal 'https://github.com/buzzsprout/buzzsprout-cli', out.strip
    end
  end

  def test_install_from_local_checkout
    Dir.mktmpdir('buzzsprout-install') do |home|
      bin = File.join(home, '.local', 'bin')
      env = install_env(home, bin)
      status, out, err = run_install(env, chdir: repo_root)
      assert_equal 0, status, "install failed\n#{out}\n#{err}"
      exe = File.join(bin, 'buzzsprout')
      assert File.executable?(exe), "missing #{exe}\n#{out}\n#{err}"
      version, = Open3.capture2(env, exe, 'version', chdir: home)
      assert_match(/0\.1\.0/, version)
      assert_includes out, 'buzzsprout login'
      assert_includes out, 'local checkout'
    end
  end

  def test_install_clones_into_cache_dir
    Dir.mktmpdir('buzzsprout-install') do |home|
      bin = File.join(home, '.local', 'bin')
      cache = File.join(home, '.buzzsprout-cli')
      env = install_env(home, bin)
      env['BUZZSPROUT_CLI_REPO'] = repo_root
      env['BUZZSPROUT_CLI_REF'] = current_ref
      env['BUZZSPROUT_CLI_HOME'] = cache
      status, out, err = run_install(env, chdir: Dir.tmpdir)
      assert_equal 0, status, "clone install failed\n#{out}\n#{err}"
      assert File.directory?(File.join(cache, '.git'))
      exe = File.join(bin, 'buzzsprout')
      assert File.executable?(exe), "missing #{exe}\n#{out}\n#{err}"
      assert_equal File.realpath(File.join(cache, 'bin', 'buzzsprout')), File.realpath(exe)
      version, = Open3.capture2(env, exe, 'version', chdir: home)
      assert_match(/0\.1\.0/, version)
    end
  end

  def test_install_refuses_to_clobber_non_repo_home
    Dir.mktmpdir('buzzsprout-install') do |home|
      bin = File.join(home, '.local', 'bin')
      cache = File.join(home, '.buzzsprout-cli')
      File.write(cache, 'nope')
      env = install_env(home, bin)
      env['BUZZSPROUT_CLI_REPO'] = repo_root
      env['BUZZSPROUT_CLI_REF'] = current_ref
      env['BUZZSPROUT_CLI_HOME'] = cache
      status, out, err = run_install(env, chdir: Dir.tmpdir)
      refute_equal 0, status
      assert_match(/refusing to overwrite/, "#{out}#{err}")
      assert_equal 'nope', File.read(cache)
    end
  end

  private

  def current_ref
    branch = `git -C #{repo_root} rev-parse --abbrev-ref HEAD`.strip
    return branch unless branch.empty? || branch == 'HEAD'

    `git -C #{repo_root} rev-parse HEAD`.strip
  end

  def install_env(home, bin)
    {
      'HOME' => home,
      'GEM_HOME' => nil,
      'GEM_PATH' => nil,
      'BUNDLE_GEMFILE' => nil,
      'RUBYLIB' => '',
      'RUBYOPT' => '',
      'BUZZSPROUT_CLI_BIN' => bin,
      'PATH' => "#{bin}:#{ENV['PATH']}"
    }
  end

  def run_install(env, chdir:)
    out, err, status = Open3.capture3(env, 'bash', script, chdir: chdir)
    [status.exitstatus, out, err]
  end
end

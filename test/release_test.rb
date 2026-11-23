# frozen_string_literal: true

require 'open3'
require_relative 'test_helper'

class ReleaseTest < Buzzsprout::Test
  def script
    File.expand_path('../script/release', __dir__)
  end

  def formula_script
    File.expand_path('../script/homebrew-formula', __dir__)
  end

  def test_release_bumps_version_and_creates_matching_tag
    with_release_repo do |root|
      status, out, err = run_release(root, '0.1.1')
      assert_equal 0, status, "#{out}\n#{err}"
      assert_includes File.read(File.join(root, 'lib/buzzsprout/version.rb')), "VERSION = '0.1.1'"
      assert_includes File.read(File.join(root, 'README.md')), 'BuzzsproutCLI/0.1.1'
      assert_includes File.read(File.join(root, 'skills/buzzsprout/SKILL.md')), 'BuzzsproutCLI/0.1.1'
      assert_equal 'Bump version to 0.1.1.', git(root, 'log', '-1', '--format=%s')
      assert_equal git(root, 'rev-parse', 'HEAD'), git(root, 'rev-parse', 'v0.1.1^{}')
      assert_includes out, 'git push --atomic origin HEAD v0.1.1'
      assert_empty git(root, 'status', '--porcelain')
    end
  end

  def test_release_push_sends_the_branch_and_tag
    with_release_repo do |root|
      Dir.mktmpdir('buzzsprout-remote') do |remote_parent|
        remote = File.join(remote_parent, 'remote.git')
        git(root, 'init', '--bare', remote)
        git(root, 'remote', 'add', 'origin', remote)
        status, out, err = run_release(root, '0.2.0', '--push')
        assert_equal 0, status, "#{out}\n#{err}"
        assert_includes out, 'Pushed main and v0.2.0'
        assert_equal git(root, 'rev-parse', 'v0.2.0'), git(remote, 'rev-parse', 'v0.2.0')
        assert_equal git(root, 'rev-parse', 'main'), git(remote, 'rev-parse', 'main')
      end
    end
  end

  def test_release_refuses_dirty_trees_other_branches_and_older_versions
    with_release_repo do |root|
      version = File.read(File.join(root, 'lib/buzzsprout/version.rb'))
      File.write(File.join(root, 'notes'), 'keep')
      status, _out, err = run_release(root, '0.1.1')
      refute_equal 0, status
      assert_match(/local changes/, err)
      assert_equal version, File.read(File.join(root, 'lib/buzzsprout/version.rb'))
      File.delete(File.join(root, 'notes'))

      git(root, 'checkout', '-b', 'feature')
      status, _out, err = run_release(root, '0.1.1')
      refute_equal 0, status
      assert_match(/main/, err)

      git(root, 'checkout', 'main')
      status, _out, err = run_release(root, '0.0.1')
      refute_equal 0, status
      assert_match(/greater than/, err)
      assert_equal version, File.read(File.join(root, 'lib/buzzsprout/version.rb'))
      _tag, tag_err, tag_status = Open3.capture3('git', '-C', root, 'rev-parse', '--verify', 'refs/tags/v0.1.1')
      refute tag_status.success?, tag_err
    end
  end

  def test_homebrew_formula_includes_the_tag_archive_and_executable
    _out, err, status = Open3.capture3('bash', formula_script)
    refute status.success?
    assert_match(/usage/, err)

    out, err, status = Open3.capture3('bash', formula_script, '0.1.1', 'a' * 64)
    assert status.success?, err
    assert_includes out, 'class BuzzsproutCli < Formula'
    assert_includes out, 'archive/refs/tags/v0.1.1.tar.gz'
    assert_includes out, 'a' * 64
    assert_includes out, 'depends_on "ruby"'
    assert_includes out, 'write_env_script'
    assert_includes out, 'buzzsprout version'
  end

  private

  def with_release_repo
    Dir.mktmpdir('buzzsprout-release') do |root|
      git(root, 'init', '-b', 'main')
      git(root, 'config', 'user.name', 'Test')
      git(root, 'config', 'user.email', 'test@example.com')
      git(root, 'config', 'commit.gpgsign', 'false')
      git(root, 'config', 'tag.gpgsign', 'false')
      FileUtils.mkdir_p(File.join(root, 'lib/buzzsprout'))
      FileUtils.mkdir_p(File.join(root, 'skills/buzzsprout'))
      File.write(File.join(root, 'lib/buzzsprout/version.rb'), "module Buzzsprout\n  VERSION = '0.1.0'\nend\n")
      File.write(File.join(root, 'README.md'), "User-Agent: BuzzsproutCLI/0.1.0\n")
      File.write(File.join(root, 'skills/buzzsprout/SKILL.md'), "User-Agent: BuzzsproutCLI/0.1.0\n")
      FileUtils.mkdir_p(File.join(root, 'script'))
      FileUtils.cp(script, File.join(root, 'script/release'))
      git(root, 'add', '.')
      git(root, 'commit', '-m', 'Initial')
      yield root
    end
  end

  def run_release(root, *args)
    out, err, status = Open3.capture3('bash', File.join(root, 'script/release'), *args, chdir: root)
    [status.exitstatus, out, err]
  end

  def git(root, *args)
    out, err, result = Open3.capture3('git', '-C', root, *args)
    assert result.success?, err
    out.strip
  end
end

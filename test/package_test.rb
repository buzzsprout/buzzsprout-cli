# frozen_string_literal: true

require 'open3'
require 'rubygems/package'
require_relative 'test_helper'

class PackageTest < Buzzsprout::Test
  def repo_root
    File.expand_path('..', __dir__)
  end

  def verify_script
    File.join(repo_root, 'script/verify-gem')
  end

  def test_built_gem_includes_executable_and_skills
    gem_path = File.join(repo_root, "buzzsprout-cli-#{Buzzsprout::VERSION}.gem")
    FileUtils.rm_f(gem_path)
    _out, err, status = Open3.capture3('gem', 'build', 'buzzsprout-cli.gemspec', chdir: repo_root)
    assert status.success?, err
    assert File.file?(gem_path), err

    out, verify_err, verify = Open3.capture3({ 'GITHUB_REF_NAME' => "v#{Buzzsprout::VERSION}" }, 'ruby', verify_script, gem_path)
    assert verify.success?, "#{out}\n#{verify_err}"
    assert_match(/executable buzzsprout/, out)
    assert_match(/#{Regexp.escape(Buzzsprout::VERSION)}/, out)

    mismatch, mismatch_err, mismatch_status = Open3.capture3({ 'GITHUB_REF_NAME' => 'v9.9.9' }, 'ruby', verify_script, gem_path)
    refute mismatch_status.success?
    assert_match(/does not match/, "#{mismatch}\n#{mismatch_err}")
  ensure
    FileUtils.rm_f(gem_path) if gem_path
  end

  def test_verify_gem_rejects_a_package_without_the_executable_or_skills
    Dir.mktmpdir do |dir|
      spec = Gem::Specification.new do |built|
        built.name = 'buzzsprout-cli'
        built.version = Buzzsprout::VERSION
        built.authors = ['Test']
        built.summary = 'incomplete package'
        built.files = []
      end
      capture_io { Dir.chdir(dir) { Gem::Package.build(spec) } }
      gem_path = File.join(dir, "buzzsprout-cli-#{Buzzsprout::VERSION}.gem")
      _out, err, status = Open3.capture3('ruby', verify_script, gem_path)
      refute status.success?
      assert_match(/buzzsprout/, err)
      assert_match(/SKILL\.md/, err)
    end
  end
end
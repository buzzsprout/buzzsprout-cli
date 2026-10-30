# frozen_string_literal: true

require_relative 'test_helper'

class SkillsContentTest < Buzzsprout::Test
  def test_each_skill_has_frontmatter_and_cli_section
    root = File.expand_path('../skills', __dir__)
    dirs = Dir.children(root).select { |name| File.directory?(File.join(root, name)) }
    refute_empty dirs
    dirs.each do |name|
      path = File.join(root, name, 'SKILL.md')
      assert File.file?(path), "missing #{path}"
      text = File.read(path)
      assert_match(/\A---\n/, text)
      assert_match(/^name: /, text)
      assert_match(/^description: /, text)
      if name == 'team'
        assert_match(/sign in to Buzzsprout/, text)
        assert_match(/web app/, text)
        next
      end
      assert_match(/Authorization: Token token=/, text)
      assert_match(/User-Agent:/, text)
      assert_match(/## CLI/, text)
      assert_match(/buzzsprout /, text)
    end

    overview = File.read(File.join(root, 'buzzsprout', 'SKILL.md'))
    assert_match(/Never read `~\/\.buzzsprout\.json`/, overview)
    assert_match(/Never print, echo, or interpolate `BUZZSPROUT_API_TOKEN`/, overview)
    refute_match(/login --token "\$BUZZSPROUT_API_TOKEN"/, overview)
    assert_match(/login --install-skills/, overview)
    assert_match(/offers to install or refresh these skills/, overview)
  end

  def test_installed_is_false_until_every_skill_is_copied
    dest = File.join(@skills_dir, 'partial')
    refute Buzzsprout::Commands::Skills.installed?(dest)

    FileUtils.mkdir_p(File.join(dest, 'podcasts'))
    File.write(File.join(dest, 'podcasts', 'SKILL.md'), '# partial')
    refute Buzzsprout::Commands::Skills.installed?(dest)

    io = StringIO.new
    copied = Buzzsprout::Commands::Skills.install_into!(dest, io: io)
    assert Buzzsprout::Commands::Skills.installed?(dest)
    refute_empty copied
    assert_match(/Installed #{copied.size} skills into #{dest}/, io.string)
    assert File.file?(File.join(dest, 'buzzsprout', 'SKILL.md'))
  end
  def test_detects_agents_and_honors_explicit_destination
    ENV.delete('BUZZSPROUT_SKILLS_DIR')
    Dir.mktmpdir do |home|
      assert_empty Buzzsprout::Commands::Skills.destination_dirs(home: home)
      FileUtils.mkdir_p(File.join(home, '.claude'))
      assert_equal [File.join(home, '.claude/skills')], Buzzsprout::Commands::Skills.destination_dirs(home: home)
      FileUtils.mkdir_p(File.join(home, '.cursor'))
      assert_equal 2, Buzzsprout::Commands::Skills.destination_dirs(home: home).size
      ENV['BUZZSPROUT_SKILLS_DIR'] = File.join(home, 'override')
      assert_equal [File.join(home, 'override')], Buzzsprout::Commands::Skills.destination_dirs(home: home)
      assert_equal [File.join(home, 'explicit')], Buzzsprout::Commands::Skills.destination_dirs(File.join(home, 'explicit'), home: home)
    end
  end

  def test_refresh_preserves_unrelated_skills_and_archives_legacy_buzzsprout_skills
    dest = File.join(@skills_dir, 'skills')
    FileUtils.mkdir_p(File.join(dest, 'stats'))
    File.write(File.join(dest, 'stats/SKILL.md'), 'Unrelated statistics skill')
    source = Buzzsprout::Commands::Skills.source_dir
    FileUtils.cp_r(File.join(source, 'episodes'), File.join(dest, 'episodes'))
    io = StringIO.new
    Buzzsprout::Commands::Skills.install_into!(dest, io: io)
    assert_equal 'Unrelated statistics skill', File.read(File.join(dest, 'stats/SKILL.md'))
    assert File.file?(File.join(dest, 'buzzsprout-stats/SKILL.md'))
    refute File.exist?(File.join(dest, 'episodes'))
    assert_equal 1, Dir.glob(File.join(@skills_dir, 'buzzsprout-skill-backups/*/episodes/SKILL.md')).size
    target = File.join(dest, 'buzzsprout-stats/SKILL.md')
    File.open(target, 'a') { |f| f.puts 'Old local guidance' }
    refute Buzzsprout::Commands::Skills.installed?(dest)
    Buzzsprout::Commands::Skills.install_into!(dest, io: io)
    assert Buzzsprout::Commands::Skills.installed?(dest)
    assert Dir.glob(File.join(@skills_dir, 'buzzsprout-skill-backups/*/buzzsprout-stats/SKILL.md')).any? { |p| File.read(p).include?('Old local guidance') }
  end

  def test_install_refuses_unrelated_namespaced_target
    dest = File.join(@skills_dir, 'conflict')
    FileUtils.mkdir_p(File.join(dest, 'buzzsprout-stats'))
    path = File.join(dest, 'buzzsprout-stats/SKILL.md')
    File.write(path, 'Unrelated')
    assert_raises(RuntimeError) { Buzzsprout::Commands::Skills.install_into!(dest, io: StringIO.new) }
    assert_equal 'Unrelated', File.read(path)
    refute File.exist?(File.join(dest, 'buzzsprout'))
  end

  def test_install_command_populates_both_detected_agents
    ENV.delete('BUZZSPROUT_SKILLS_DIR')
    Dir.mktmpdir do |home|
      %w[.cursor .claude].each { |agent| FileUtils.mkdir_p(File.join(home, agent)) }
      Dir.stub(:home, home) do
        status, out, err = run_cli(['skills', 'install'])
        assert_equal 0, status, err
        %w[.cursor .claude].each do |agent|
          destination = File.join(home, agent, 'skills')
          assert Buzzsprout::Commands::Skills.installed?(destination)
          assert_includes out, destination
        end
      end
    end
  end

end

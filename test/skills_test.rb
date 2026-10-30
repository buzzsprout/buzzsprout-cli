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
    assert_match(/offer to install these skills/, overview)
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
end

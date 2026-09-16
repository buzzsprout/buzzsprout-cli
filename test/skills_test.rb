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
      assert_match(/Authorization: Token token=/, text)
      assert_match(/User-Agent:/, text)
      assert_match(/## CLI/, text)
      assert_match(/buzzsprout /, text)
    end
  end
end

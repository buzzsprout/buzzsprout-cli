# frozen_string_literal: true

require_relative 'test_helper'

class OptionsTest < Buzzsprout::Test
  def test_parses_global_and_field_flags
    args = ['episodes', 'create', '10', '--title', 'Hello', '--private', '--json', '--body', '{"episode_number":3}']
    options = Buzzsprout::Options.parse!(args)
    assert_equal %w[episodes create 10], args
    assert options.json?
    assert_equal true, options.fields['private']
    assert_equal 'Hello', options.fields['title']
    assert_equal 3, options.merge_body['episode_number']
    assert_equal 'Hello', options.merge_body['title']
  end

  def test_equals_form
    args = ['--date=2026-09-12', '--token=abc']
    options = Buzzsprout::Options.parse!(args)
    assert_equal '2026-09-12', options.fields['date']
    assert_equal 'abc', options.token
    assert_empty args
  end

  def test_podcast_flag_and_in_alias
    args = ['episodes', 'list', '--podcast', '10']
    options = Buzzsprout::Options.parse!(args)
    assert_equal '10', options.podcast_id
    assert_equal %w[episodes list], args

    args = ['episodes', 'list', '--in=20']
    options = Buzzsprout::Options.parse!(args)
    assert_equal '20', options.podcast_id
    assert_equal %w[episodes list], args

    args = ['--podcast', '10', '--in', '20']
    options = Buzzsprout::Options.parse!(args)
    assert_equal '10', options.podcast_id
  end

  def test_skills_install_flags
    args = ['login', '--install-skills', '--dir', '/tmp/skills']
    options = Buzzsprout::Options.parse!(args)
    assert options.install_skills?
    refute options.skip_skills?
    assert_equal '/tmp/skills', options.dir
    assert_equal %w[login], args

    args = ['login', '--no-skills']
    options = Buzzsprout::Options.parse!(args)
    assert options.skip_skills?
    refute options.install_skills?

    args = ['login', '--skip-skills', '--dir=~/.cursor/skills']
    options = Buzzsprout::Options.parse!(args)
    assert options.skip_skills?
    assert_equal '~/.cursor/skills', options.dir
  end
end

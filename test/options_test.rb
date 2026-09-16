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
end

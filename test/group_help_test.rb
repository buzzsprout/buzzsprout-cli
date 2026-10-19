# frozen_string_literal: true

require_relative 'test_helper'

class GroupHelpTest < Buzzsprout::Test
  def test_printer_emits_basecamp_sections
    io = StringIO.new
    Buzzsprout::GroupHelp.print(
      {
        summary: 'Show download totals for one day (podcast or episode).',
        usage: ['buzzsprout downloads today|yesterday|YYYY-MM-DD'],
        aliases: %w[downloads stats],
        commands: [['episode <id> downloads DATE', 'Per-listener downloads']],
        flags: [['--date DATE', 'Alternate to a positional date']],
        examples: ['buzzsprout downloads today'],
        name: 'downloads'
      },
      io: io
    )
    out = io.string
    assert_match(/Show download totals/, out)
    assert_match(/USAGE/, out)
    assert_match(/ALIASES/, out)
    assert_match(/downloads, stats/, out)
    assert_match(/COMMANDS/, out)
    assert_match(/FLAGS/, out)
    assert_match(/INHERITED FLAGS/, out)
    assert_match(/--json/, out)
    assert_match(/EXAMPLES/, out)
    assert_match(/\$ buzzsprout downloads today/, out)
    assert_match(/LEARN MORE/, out)
    assert_match(/buzzsprout downloads --help/, out)
  end
end

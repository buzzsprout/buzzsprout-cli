# frozen_string_literal: true

require_relative 'test_helper'

class GroupHelpTest < Buzzsprout::Test
  def test_printer_emits_basecamp_sections
    io = StringIO.new
    Buzzsprout::GroupHelp.print(
      {
        summary: 'Show download stats for a podcast or episode.',
        usage: ['buzzsprout stats --date YYYY-MM-DD'],
        aliases: %w[stats downloads],
        commands: [['episode', 'Per-listener downloads']],
        flags: [['--date YYYY-MM-DD', 'Day to report (required)']],
        examples: ['buzzsprout stats --date 2026-09-16'],
        name: 'stats'
      },
      io: io
    )
    out = io.string
    assert_match(/Show download stats/, out)
    assert_match(/USAGE/, out)
    assert_match(/ALIASES/, out)
    assert_match(/stats, downloads/, out)
    assert_match(/COMMANDS/, out)
    assert_match(/FLAGS/, out)
    assert_match(/INHERITED FLAGS/, out)
    assert_match(/--json/, out)
    assert_match(/EXAMPLES/, out)
    assert_match(/\$ buzzsprout stats --date/, out)
    assert_match(/LEARN MORE/, out)
    assert_match(/buzzsprout stats --help/, out)
  end
end

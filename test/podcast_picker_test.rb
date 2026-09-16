# frozen_string_literal: true

require_relative 'test_helper'

class PodcastPickerTest < Buzzsprout::Test
  PODCASTS = [
    { 'id' => 10, 'title' => 'Life Empowerment' },
    { 'id' => 20, 'title' => 'Youth Podcast' },
    { 'id' => 30, 'title' => 'Tech Talk' }
  ].freeze

  def test_filter_narrows_by_title_and_selects
    picker = Buzzsprout::PodcastPicker.new(PODCASTS, io: StringIO.new, stdin: StringIO.new)
    'youth'.each_char { |ch| picker.handle_key(ch) }
    assert_equal 1, picker.filtered.size
    assert_equal 20, picker.highlighted['id']
    assert_equal :selected, picker.handle_key(:enter)
  end

  def test_filter_matches_id
    picker = Buzzsprout::PodcastPicker.new(PODCASTS, io: StringIO.new, stdin: StringIO.new)
    picker.handle_key('3')
    picker.handle_key('0')
    assert_equal 30, picker.highlighted['id']
  end

  def test_arrows_move_highlight
    picker = Buzzsprout::PodcastPicker.new(PODCASTS, io: StringIO.new, stdin: StringIO.new)
    assert_equal 10, picker.highlighted['id']
    picker.handle_key(:down)
    assert_equal 20, picker.highlighted['id']
    picker.handle_key(:down)
    assert_equal 30, picker.highlighted['id']
    picker.handle_key(:down)
    assert_equal 10, picker.highlighted['id']
    picker.handle_key(:up)
    assert_equal 30, picker.highlighted['id']
  end

  def test_default_id_pre_highlights
    picker = Buzzsprout::PodcastPicker.new(PODCASTS, io: StringIO.new, stdin: StringIO.new, default_id: 20)
    assert_equal 20, picker.highlighted['id']
  end

  def test_backspace_and_ctrl_u_edit_filter
    picker = Buzzsprout::PodcastPicker.new(PODCASTS, io: StringIO.new, stdin: StringIO.new)
    'youthx'.each_char { |ch| picker.handle_key(ch) }
    assert_empty picker.filtered
    picker.handle_key(:backspace)
    assert_equal 20, picker.highlighted['id']
    picker.handle_key(:ctrl_u)
    assert_equal 3, picker.filtered.size
  end

  def test_esc_and_ctrl_c_cancel
    picker = Buzzsprout::PodcastPicker.new(PODCASTS, io: StringIO.new, stdin: StringIO.new)
    assert_equal :cancelled, picker.handle_key(:esc)
    assert_equal :cancelled, picker.handle_key(:ctrl_c)
  end

  def test_enter_on_empty_filter_is_noop
    picker = Buzzsprout::PodcastPicker.new(PODCASTS, io: StringIO.new, stdin: StringIO.new)
    'zzz'.each_char { |ch| picker.handle_key(ch) }
    assert_equal :empty, picker.handle_key(:enter)
  end

  def test_select_bang_reads_arrows_and_enter
    stdin = StringIO.new("\e[B\r")
    io = StringIO.new
    chosen = Buzzsprout::PodcastPicker.new(PODCASTS, io: io, stdin: stdin).select!
    assert_equal 20, chosen['id']
    assert_includes io.string, 'Youth Podcast - #20'
    assert_includes io.string, 'Select a podcast'
  end

  def test_rows_lead_with_title_then_id
    stdin = StringIO.new("\r")
    io = StringIO.new
    Buzzsprout::PodcastPicker.new(PODCASTS, io: io, stdin: stdin).select!
    output = io.string
    assert_includes output, 'Life Empowerment - #10'
    assert_includes output, 'Youth Podcast - #20'
    assert_includes output, 'Tech Talk - #30'
    refute_match(/\d+\s{2}Life Empowerment/, output)
  end

  def test_rows_dim_id_when_color_enabled
    ENV.delete('NO_COLOR')
    ENV.delete('BUZZSPROUT_NO_COLOR')
    stdin = StringIO.new("\r")
    io = Buzzsprout::FakeTty.new
    Buzzsprout::PodcastPicker.new(PODCASTS, io: io, stdin: stdin).select!
    assert_match(/\e\[2m - #10\e\[0m/, io.string)
  end

  def test_select_bang_filter_then_enter
    stdin = StringIO.new("tech\r")
    io = StringIO.new
    chosen = Buzzsprout::PodcastPicker.new(PODCASTS, io: io, stdin: stdin).select!
    assert_equal 30, chosen['id']
    assert_includes io.string, 'Search: tech'
  end

  def test_select_redraws_in_place_without_stacking
    stdin = StringIO.new("\e[B\e[B\r")
    io = StringIO.new
    chosen = Buzzsprout::PodcastPicker.new(PODCASTS, io: io, stdin: stdin).select!
    assert_equal 30, chosen['id']
    output = io.string
    assert_includes output, "\e7"
    assert_includes output, "\e8"
    assert_includes output, "\e[0J"
    assert_includes output, "\e[2K"
    assert_includes output, 'Search:'
    %w[Life\ Empowerment Youth\ Podcast Tech\ Talk].each do |title|
      assert_includes output, title
    end
    save_at = output.index("\e7")
    refute_nil save_at
    after_save = output[save_at + 2..]
    refute_match(/\e\[\d+A/, after_save, 'redraws must restore the saved origin, not CSI-A stack')
    assert_operator output.scan("\e8").size, :>=, 2
  end

  def test_select_bang_esc_cancels
    stdin = StringIO.new("\e")
    io = StringIO.new
    error = assert_raises(Buzzsprout::PodcastPicker::Cancelled) do
      Buzzsprout::PodcastPicker.new(PODCASTS, io: io, stdin: stdin).select!
    end
    assert_match(/cancelled/, error.message)
  end

  def test_choose_auto_selects_single_podcast
    chosen = Buzzsprout::PodcastPicker.choose!(
      [{ 'id' => 10, 'title' => 'Only Show' }],
      io: StringIO.new,
      stdin: StringIO.new('this should not be read')
    )
    assert_equal 10, chosen['id']
  end

  def test_choose_raises_when_empty
    error = assert_raises(RuntimeError) do
      Buzzsprout::PodcastPicker.choose!([], io: StringIO.new, stdin: StringIO.new)
    end
    assert_match(/No podcasts/, error.message)
  end

  def test_interactive_false_for_json_and_noninteractive_env
    stdin = Buzzsprout::FakeTty.new
    assert Buzzsprout::PodcastPicker.interactive?(stdin: stdin, json: false)
    refute Buzzsprout::PodcastPicker.interactive?(stdin: stdin, json: true)
    ENV['BUZZSPROUT_NONINTERACTIVE'] = '1'
    refute Buzzsprout::PodcastPicker.interactive?(stdin: stdin, json: false)
  end

  def test_interactive_false_without_tty
    refute Buzzsprout::PodcastPicker.interactive?(stdin: StringIO.new, json: false)
  end
end

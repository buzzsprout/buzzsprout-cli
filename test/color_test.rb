# frozen_string_literal: true

require 'minitest/mock'
require_relative 'test_helper'

class ColorThemeTest < Buzzsprout::Test
  def test_theme_override_env
    ENV['BUZZSPROUT_THEME'] = 'dark'
    ENV['COLORFGBG'] = '0;15'
    Buzzsprout::Color.reset_theme!
    assert_equal :dark, Buzzsprout::Color.theme

    ENV['BUZZSPROUT_THEME'] = 'LIGHT'
    Buzzsprout::Color.reset_theme!
    assert_equal :light, Buzzsprout::Color.theme
  end

  def test_theme_from_colorfgbg
    ENV['COLORFGBG'] = '15;0'
    Buzzsprout::Color.reset_theme!
    assert_equal :dark, Buzzsprout::Color.theme

    ENV['COLORFGBG'] = '0;15'
    Buzzsprout::Color.reset_theme!
    assert_equal :light, Buzzsprout::Color.theme

    ENV['COLORFGBG'] = '0;7'
    Buzzsprout::Color.reset_theme!
    assert_equal :light, Buzzsprout::Color.theme

    ENV['COLORFGBG'] = '7;0'
    Buzzsprout::Color.reset_theme!
    assert_equal :dark, Buzzsprout::Color.theme
  end

  def test_theme_defaults_to_dark
    Buzzsprout::Color.reset_theme!
    assert_equal :dark, Buzzsprout::Color.theme
  end

  def test_parse_osc11_luma
    assert_equal :dark, Buzzsprout::Color.parse_osc11("\e]11;rgb:0000/0000/0000\a")
    assert_equal :light, Buzzsprout::Color.parse_osc11("\e]11;rgb:ffff/ffff/ffff\e\\")
    assert_equal :light, Buzzsprout::Color.parse_osc11('rgb:ff/ff/ff')
    assert_nil Buzzsprout::Color.parse_osc11('')
  end

  def test_osc11_probe_used_when_no_env
    ENV.delete('CI')
    Buzzsprout::Color.reset_theme!
    Buzzsprout::Color.stub(:probe_osc11, :light) do
      assert_equal :light, Buzzsprout::Color.detect_theme(StringIO.new)
    end
  end

  def test_osc11_probe_does_not_emit_to_ui_streams
    ui = StringIO.new
    err = StringIO.new
    # Ghostty-style reply that previously leaked above "Welcome".
    reply = "\e]11;rgb:2828/2c2c/3434\e\\"
    tty = FakeOscTty.new(reply)

    captured_err = +''
    orig_err = $stderr
    $stderr = err
    begin
      theme = Buzzsprout::Color.probe_osc11(ui, tty: tty)
    ensure
      $stderr = orig_err
    end

    assert_equal :dark, theme
    assert tty.raw_entered, 'OSC 11 must run with echo off (raw)'
    assert tty.raw_exited, 'terminal mode must be restored'
    assert tty.consumed?, 'full OSC reply must be read/discarded'
    refute_match(/11;|rgb:/, ui.string)
    refute_match(/11;|rgb:/, err.string)
    refute_includes ui.string, "\e"
    assert_includes tty.written, ']11;?'
  end

  def test_osc11_probe_skips_when_not_raw_capable
    ui = StringIO.new
    tty = Object.new
    def tty.tty? = true
    def tty.write(*) = raise('must not write OSC without raw/no-echo')

    assert_nil Buzzsprout::Color.probe_osc11(ui, tty: tty)
    assert_equal '', ui.string
  end

  def test_osc11_probe_skips_when_tty_is_the_ui_stream
    ui = FakeOscTty.new("\e]11;rgb:ffff/ffff/ffff\a")
    assert_nil Buzzsprout::Color.probe_osc11(ui, tty: ui)
    refute_includes ui.written, ']11;?'
  end

  class FakeOscTty
    attr_reader :written, :raw_entered, :raw_exited

    def initialize(reply)
      @reply = reply.b
      @pos = 0
      @written = +''
      @raw_entered = false
      @raw_exited = false
    end

    def tty?
      true
    end

    def write(str)
      @written << str
      str.bytesize
    end

    def flush; end

    def raw
      @raw_entered = true
      yield self
    ensure
      @raw_exited = true
    end

    def read_nonblock(size, *)
      raise Errno::EAGAIN if @pos >= @reply.bytesize

      chunk = @reply.byteslice(@pos, size)
      @pos += chunk.bytesize
      chunk
    end

    def consumed?
      @pos >= @reply.bytesize
    end
  end
end

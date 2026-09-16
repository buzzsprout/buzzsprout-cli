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
end

# frozen_string_literal: true

require_relative 'test_helper'

class AnimationTest < Buzzsprout::Test
  def test_wordmark_is_embedded_braille
    root = File.expand_path('..', __dir__)
    refute File.exist?(File.join(root, 'assets')), 'logo files must not live under assets/'
    refute File.exist?(File.join(root, 'script', 'generate_logo_frames'))

    leftovers = Dir.glob(File.join(root, '{lib,bin,test,skills}/**/*.{svg,png,jpg,jpeg,gif,webp}'))
    leftovers += Dir.glob(File.join(root, '*.{svg,png,jpg,jpeg,gif,webp}'))
    leftovers.reject! { |path| path.include?('/vendor/') }
    assert_empty leftovers, "binary logo leftovers: #{leftovers.join(', ')}"

    source = File.read(File.expand_path('../lib/buzzsprout/animation.rb', __dir__))
    refute_match(/frames\.json|\.svg|\.png/, source)

    assert_equal 76, Buzzsprout::Animation::WORDMARK.first.chars.length
    Buzzsprout::Animation::WORDMARK.each do |line|
      assert_equal Buzzsprout::Animation::WIDTH, line.chars.length
    end
    Buzzsprout::Animation::KIND.each do |line|
      assert_equal Buzzsprout::Animation::WIDTH, line.chars.length
    end
  end

  def test_frames_are_uniform_and_animate
    frames = Buzzsprout::Animation.frames
    assert_operator frames.size, :>=, 8
    height = Buzzsprout::Animation.height
    width = Buzzsprout::Animation.width
    frames.each do |frame|
      assert_equal height, frame['text'].size
      assert_equal height, frame['kind'].size
      frame['text'].each { |line| assert_equal width, line.chars.length }
    end
  end

  def test_finale_is_the_default_wordmark
    last = Buzzsprout::Animation.frames.last['text'].join
    assert_equal Buzzsprout::Animation::WORDMARK.join, last
    assert_includes last, '⣿'
    assert_operator last.count('⣿'), :>, 80
  end

  def test_play_with_force_writes_braille_logo
    io = StringIO.new
    Buzzsprout::Animation.new(io: io, delay: 0, force: true).play
    assert_includes io.string, '⣿'
  end

  def test_play_leaves_wordmark_visible
    io = StringIO.new
    Buzzsprout::Animation.new(io: io, delay: 0, force: true).play
    output = io.string
    last_braille = output.rindex('⣿')
    refute_nil last_braille
    after = output[last_braille..]
    refute_includes after, "\e8", 'DECSC restore must not run after the finale wordmark'
    refute_includes after, "\e[u", 'SCORC restore must not run after the finale wordmark'
    refute_includes after, "\e[0J", 'ED must not wipe the wordmark after it is shown'
    assert_includes output, "\e[2K"
  end

  def test_fireworks_skipped_on_non_tty
    io = StringIO.new
    refute Buzzsprout::Animation.new(io: io, delay: 0).play_fireworks
    assert_equal '', io.string
  end

  def test_fireworks_skipped_in_ci
    ENV.delete('BUZZSPROUT_NO_ANIMATION')
    io = FakeTty.new
    refute Buzzsprout::Animation.new(io: io, delay: 0).play_fireworks
    assert_equal '', io.string
  end

  def test_fireworks_skipped_when_no_animation_env
    ENV.delete('CI')
    ENV['BUZZSPROUT_NO_ANIMATION'] = '1'
    io = FakeTty.new
    refute Buzzsprout::Animation.new(io: io, delay: 0).play_fireworks
    assert_equal '', io.string
  end

  def test_fireworks_force_plays_and_leaves_phrase
    io = StringIO.new
    assert Buzzsprout::Animation.new(io: io, delay: 0, force: true).play_fireworks
    output = io.string
    assert_includes output, "You're in!"
    assert_match(/[|*+.]/, output)
    refute_includes output, "\e7"
    refute_includes output, "\e8"
    refute_includes output, "\e[0J"
    last_phrase = output.rindex("You're in!")
    refute_nil last_phrase
    after = output[last_phrase..]
    refute_includes after, "\e[0J"
  end

  def test_fireworks_frames_keep_phrase_on_every_frame
    io = StringIO.new
    frames = Buzzsprout::Animation.new(io: io, delay: 0, force: true).fireworks_frames
    assert_operator frames.size, :>=, 12
    frames.each do |lines|
      assert lines.any? { |line| line.include?("You're in!") }, 'phrase must ride with the bursts'
    end
    assert_equal "You're in!", frames.last[Buzzsprout::Animation::FIREWORKS_HEIGHT / 2].strip
  end

  def test_icon_grows_before_wordmark
    frames = Buzzsprout::Animation.frames
    early = frames[2]['text'].join
    finale = frames.last['text']
    # Early frames only use the left (mark) columns.
    mark = Buzzsprout::Animation.icon_columns
    early_right = frames[2]['text'].map { |line| line.chars[mark..].join }.join
    refute_match(/\S/, early_right)
    assert_match(/\S/, early)
    assert_match(/\S/, finale.map { |line| line.chars[mark..].join }.join)
  end

  def test_dark_theme_colors_wordmark_bright_green
    ENV.delete('NO_COLOR')
    ENV['BUZZSPROUT_THEME'] = 'dark'
    Buzzsprout::Color.reset_theme!
    io = FakeTty.new
    lines = Buzzsprout::Animation.new(io: io, delay: 0, force: true).send(:colorize, Buzzsprout::Animation.frames.last)
    joined = lines.join
    assert_includes joined, '38;2;97;215;82'
    refute_includes joined, '38;2;33;69;56'
  end

  def test_light_theme_keeps_dark_mark_and_bright_bolt
    ENV.delete('NO_COLOR')
    ENV['BUZZSPROUT_THEME'] = 'light'
    Buzzsprout::Color.reset_theme!
    io = FakeTty.new
    lines = Buzzsprout::Animation.new(io: io, delay: 0, force: true).send(:colorize, Buzzsprout::Animation.frames.last)
    joined = lines.join
    assert_includes joined, '38;2;97;215;82'
    assert_includes joined, '38;2;33;69;56'
  end

  class FakeTty < StringIO
    def tty?
      true
    end
  end
end

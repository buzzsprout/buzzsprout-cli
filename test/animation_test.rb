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
end

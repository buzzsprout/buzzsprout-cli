# frozen_string_literal: true

require_relative 'test_helper'

class AnimationTest < Buzzsprout::Test
  def test_frames_load_from_logo_assets
    assert File.file?(Buzzsprout::Animation::FRAMES_FILE)
    frames = Buzzsprout::Animation.frames
    assert frames.size >= 8
    height = Buzzsprout::Animation.height
    width = Buzzsprout::Animation.width
    assert_operator width, :>=, 48
    frames.each do |frame|
      assert_equal height, frame['text'].size
      assert_equal height, frame['kind'].size
      frame['text'].each { |line| assert_equal width, line.length }
    end
  end

  def test_finale_is_the_default_wordmark
    last = Buzzsprout::Animation.frames.last['text'].join
    assert_includes last, '⣿'
    # Lockup includes both the mark (left) and the wordmark letters.
    assert_operator last.count('⣿'), :>, 80
  end

  def test_play_with_force_writes_braille_logo
    io = StringIO.new
    Buzzsprout::Animation.new(io: io, delay: 0, force: true).play
    assert_includes io.string, '⣿'
    refute_match(/B U Z Z S P R O U T/, io.string)
  end

  def test_source_logo_files_are_present
    dir = Buzzsprout::Animation::ASSET_DIR
    assert File.file?(File.join(dir, 'buzzsprout-logo.svg'))
    assert File.file?(File.join(dir, 'buzzsprout-wordmark.png'))
    svg = File.read(File.join(dir, 'buzzsprout-logo.svg'))
    assert_includes svg, '#61D752'
    assert_includes svg, '#214538'
  end
end

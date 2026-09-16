# frozen_string_literal: true

require_relative 'test_helper'

class AnimationTest < Buzzsprout::Test
  def test_frames_are_present_and_uniform
    frames = Buzzsprout::Animation.frames
    assert frames.size >= 8
    height = frames.first.size
    frames.each do |frame|
      assert_equal height, frame.size
      frame.each { |line| assert_equal Buzzsprout::Animation::WIDTH, line.length }
    end
    assert frames.last.any? { |line| line.include?('B U Z Z S P R O U T') }
  end

  def test_play_with_force_writes_finale
    io = StringIO.new
    Buzzsprout::Animation.new(io: io, delay: 0, force: true).play
    assert_match(/B U Z Z S P R O U T/, io.string)
    assert_match(/podcasts, take flight/, io.string)
  end
end

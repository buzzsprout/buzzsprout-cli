# frozen_string_literal: true

module Buzzsprout
  class Animation
    CONFETTI_WIDTH = 42
    CONFETTI_HEIGHT = 7
    CONFETTI_FRAMES = 10
    CONFETTI_DELAY = 0.04
    CONFETTI_CHARS = ['*', '+', '.', 'o', '~'].freeze
    CONFETTI_DARK = ['#61D752', '#A8F09A', '#F7E36D', '#FFFFFF'].freeze
    CONFETTI_LIGHT = ['#214538', '#3D7A32', '#61D752', '#C9A227'].freeze

    def confetti_frames
      rng = Random.new
      width = CONFETTI_WIDTH
      height = CONFETTI_HEIGHT
      palette = Color.theme(@io) == :light ? CONFETTI_LIGHT : CONFETTI_DARK
      particles = Array.new(28) do
        {
          x: rng.rand(width),
          y: -rng.rand(height),
          ch: CONFETTI_CHARS[rng.rand(CONFETTI_CHARS.size)],
          hex: palette[rng.rand(palette.size)],
          drift: rng.rand(3) - 1
        }
      end

      Array.new(CONFETTI_FRAMES) do
        grid = Array.new(height) { Array.new(width) { [' ', nil] } }
        particles.each do |p|
          if p[:y] >= 0 && p[:y] < height && p[:x] >= 0 && p[:x] < width
            grid[p[:y]][p[:x]] = [p[:ch], p[:hex]]
          end
          p[:y] += 1
          p[:x] = (p[:x] + p[:drift]) % width
        end
        grid.map { |row| colorize_confetti_row(row) }
      end
    end

    def colorize_confetti_row(row)
      return row.map(&:first).join unless Color.enabled?(@io)

      row.map do |char, hex|
        hex ? Color.rgb(char, hex, io: @io) : char
      end.join
    end
  end
end

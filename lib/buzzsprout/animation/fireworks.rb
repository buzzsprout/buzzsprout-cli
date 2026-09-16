# frozen_string_literal: true

module Buzzsprout
  class Animation
    FIREWORKS_WIDTH = 44
    FIREWORKS_HEIGHT = 7
    FIREWORKS_DELAY = 0.05
    FIREWORKS_PHRASE = "You're in!"
    FIREWORKS_RISE = 3
    FIREWORKS_BURST = 5
    FIREWORKS_HOLD = 3
    FIREWORKS_LIFE = FIREWORKS_RISE + FIREWORKS_BURST
    FIREWORKS_DARK = ['#61D752', '#A8F09A', '#F7E36D', '#FFFFFF'].freeze
    FIREWORKS_LIGHT = ['#214538', '#3D7A32', '#61D752', '#C9A227'].freeze
    FIREWORKS_BURSTS = [
      { x: 8, y: 1, start: 0 },
      { x: 35, y: 1, start: 4 },
      { x: 12, y: 5, start: 8 }
    ].freeze

    def fireworks_frames
      palette = Color.theme(@io) == :light ? FIREWORKS_LIGHT : FIREWORKS_DARK
      last_start = FIREWORKS_BURSTS.map { |burst| burst[:start] }.max
      total = last_start + FIREWORKS_LIFE + FIREWORKS_HOLD

      Array.new(total) do |tick|
        grid = Array.new(FIREWORKS_HEIGHT) { Array.new(FIREWORKS_WIDTH) { [' ', nil] } }
        FIREWORKS_BURSTS.each do |burst|
          paint_burst(grid, burst, tick, palette)
        end
        overlay_phrase(grid)
        grid.map { |row| colorize_fireworks_row(row) }
      end
    end

    def colorize_fireworks_row(row)
      return row.map(&:first).join unless Color.enabled?(@io)

      row.map do |char, hex|
        case hex
        when :phrase
          Color.paint(char, Color::BOLD, phrase_color, io: @io)
        when String
          Color.rgb(char, hex, io: @io)
        else
          char
        end
      end.join
    end

    private

    def paint_burst(grid, burst, tick, palette)
      age = tick - burst[:start]
      return if age.negative? || age >= FIREWORKS_LIFE

      cx = burst[:x]
      cy = burst[:y]
      if age < FIREWORKS_RISE
        rocket_y = cy + (FIREWORKS_RISE - age)
        plot_spark(grid, cx, rocket_y, age.even? ? '|' : '*', palette.first)
        return
      end

      exploded = age - FIREWORKS_RISE
      radius = [exploded, 3].min
      fading = exploded >= 3
      (-radius..radius).each do |dy|
        (-radius..radius).each do |dx|
          dist2 = (dx * dx) + (dy * dy)
          inner = radius.zero? ? -1 : (radius - 1)**2
          outer = radius.zero? ? 0 : (radius * radius) + 1
          next if dist2 < inner || dist2 > outer
          next if fading && ((dx + dy + age) % 2).odd?

          char = burst_char(dx, dy, exploded)
          hex = palette[(dx.abs + dy.abs) % palette.size]
          plot_spark(grid, cx + dx, cy + dy, char, hex)
        end
      end
    end

    def burst_char(dx, dy, exploded)
      return '*' if dx.zero? && dy.zero?
      return '.' if exploded >= 3

      %w[* + o .][(dx.abs + dy.abs) % 4]
    end

    def overlay_phrase(grid)
      phrase = FIREWORKS_PHRASE
      y = FIREWORKS_HEIGHT / 2
      x = (FIREWORKS_WIDTH - phrase.length) / 2
      phrase.chars.each_with_index do |char, index|
        plot_spark(grid, x + index, y, char, :phrase)
      end
    end

    def phrase_color
      hex = Color.theme(@io) == :light ? MARK_COLOR_LIGHT : BOLT_COLOR
      value = hex.delete('#')
      r = value[0, 2].to_i(16)
      g = value[2, 2].to_i(16)
      b = value[4, 2].to_i(16)
      "\e[38;2;#{r};#{g};#{b}m"
    end

    def plot_spark(grid, x, y, char, hex)
      return if y.negative? || y >= FIREWORKS_HEIGHT
      return if x.negative? || x >= FIREWORKS_WIDTH

      grid[y][x] = [char, hex]
    end
  end
end

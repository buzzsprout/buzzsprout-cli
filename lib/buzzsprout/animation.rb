# frozen_string_literal: true

require_relative 'animation/wordmark'

module Buzzsprout
  class Animation
    DEFAULT_DELAY = DELAY

    def initialize(io: $stdout, delay: nil, force: false)
      @io = io
      @delay = delay
      @force = force
    end

    def play
      return if skip?

      hide = "\e[?25l"
      show = "\e[?25h"
      @io.print hide
      height = nil
      delay = @delay || DELAY
      frames.each_with_index do |frame, index|
        lines = colorize(frame)
        height ||= lines.size
        @io.print "\e[#{height}A" if index.positive?
        lines.each { |line| @io.puts line }
        sleep delay
      end
    ensure
      @io.print show if @io.respond_to?(:print)
      @io.puts '' if @io.respond_to?(:puts)
    end

    def frames
      self.class.frames
    end

    def self.frames
      @frames ||= build_frames
    end

    def self.width
      WIDTH
    end

    def self.height
      HEIGHT
    end

    def self.reset!
      @frames = nil
    end

    def self.icon_columns
      occupied = Array.new(WIDTH) do |x|
        KIND.any? { |row| row.chars[x] != '.' }
      end
      x = 0
      x += 1 while x < WIDTH && !occupied[x]
      x += 1 while x < WIDTH && occupied[x]
      [x + 1, WIDTH].min
    end

    def self.build_frames
      mark = icon_columns
      frames = []
      frames << mask { |_x, _y| false }

      HEIGHT.times do |step|
        threshold = HEIGHT - (step + 1)
        frame = mask { |x, y| x < mark && y >= threshold }
        frames << frame if frame['text'].any? { |line| line.match?(/\S/) }
      end

      frames << mask { |x, _y| x < mark }

      remaining = WIDTH - mark
      wipe_steps = 8
      wipe_steps.times do |step|
        edge = mark + (remaining * (step + 1) / wipe_steps)
        frames << mask { |x, _y| x < edge }
      end

      3.times { frames << mask { |_x, _y| true } }
      frames
    end

    def self.mask
      word = WORDMARK.map(&:chars)
      kinds = KIND.map(&:chars)
      texts = []
      kind_rows = []
      HEIGHT.times do |y|
        chars = []
        ks = []
        WIDTH.times do |x|
          if yield(x, y)
            chars << (word[y][x] || ' ')
            ks << (kinds[y][x] || '.')
          else
            chars << ' '
            ks << '.'
          end
        end
        texts << chars.join
        kind_rows << ks.join
      end
      { 'text' => texts, 'kind' => kind_rows }
    end
    private_class_method :mask, :build_frames

    private

    def skip?
      return false if @force
      return true unless @io.respond_to?(:tty?) && @io.tty?
      return true if ENV['BUZZSPROUT_NO_ANIMATION'] == '1'
      return true if ENV['CI']

      false
    end

    def colorize(frame)
      frame['text'].each_with_index.map do |line, y|
        kinds = frame['kind'][y].to_s
        next line unless Color.enabled?(@io)

        kind_chars = kinds.chars
        line.chars.each_with_index.map do |char, x|
          case kind_chars[x]
          when 'b' then Color.rgb(char, bolt_hex, io: @io)
          when 'm' then Color.rgb(char, mark_hex, io: @io)
          else char
          end
        end.join
      end
    end

    def bolt_hex
      BOLT_COLOR
    end

    def mark_hex
      Color.theme(@io) == :light ? MARK_COLOR_LIGHT : MARK_COLOR_DARK
    end
  end
end

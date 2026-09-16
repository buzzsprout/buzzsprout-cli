# frozen_string_literal: true

require_relative 'animation/wordmark'
require_relative 'animation/confetti'

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

      Color.theme(@io)
      hide_cursor
      # Leave the finale wordmark on screen; auth continues below it.
      run_block(frames.map { |frame| colorize(frame) }, @delay || DELAY, erase: false)
    ensure
      show_cursor
    end

    def play_confetti
      return if skip?

      Color.theme(@io)
      hide_cursor
      run_block(confetti_frames, @delay || CONFETTI_DELAY, erase: true)
    ensure
      show_cursor
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

    def hide_cursor
      @cursor_hidden = true
      @io.print "\e[?25l" if @io.respond_to?(:print)
    end

    def show_cursor
      return unless @cursor_hidden

      @cursor_hidden = false
      @io.print "\e[?25h" if @io.respond_to?(:print)
    end

    def run_block(frames, delay, erase: false)
      height = frames.first&.size.to_i
      return if height <= 0

      # Scroll the prompt up if we are near the bottom, then remember this
      # origin. Height-only CSI A is wrong when lines wrap; save/restore is not.
      height.times { @io.print "\n" }
      @io.print "\e[#{height}A\r"
      @io.print "\e7\e[s" if erase

      frames.each_with_index do |lines, index|
        home_cursor(height) if index.positive?
        paint_lines(lines)
        sleep delay
      end
      restore_and_erase if erase
    end

    # CSI n A preserves column on some terminals (Ghostty); CR + EL so a
    # shorter/wrapped row cannot leave cells behind during in-place redraw.
    def home_cursor(height)
      return unless height&.positive?

      @io.print "\e[#{height}A\r"
    end

    def paint_lines(lines)
      lines.each do |line|
        @io.print "\e[2K#{line}\e[0m\n"
      end
    end

    def restore_and_erase
      # DECRC + SCORC back to the pre-animation origin, reset SGR, erase
      # downward. Used by confetti so debris does not linger; the intro
      # wordmark is left in place so it stays visible through auth.
      @io.print "\e8\e[u\e[0m\e[0J"
    end
  end
end

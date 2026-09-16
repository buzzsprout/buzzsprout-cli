# frozen_string_literal: true

# Placeholder ASCII frames for first-run. Replace FRAMES later with
# logo-derived art; keep a consistent line count so in-place redraw works.

module Buzzsprout
  class Animation
    WIDTH = 52
    DEFAULT_DELAY = 0.055

    def initialize(io: $stdout, delay: DEFAULT_DELAY, force: false)
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
      frames.each_with_index do |frame, index|
        lines = colorize(frame)
        height ||= lines.size
        @io.print "\e[#{height}A" if index.positive?
        lines.each { |line| @io.puts line }
        sleep @delay
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

    def self.build_frames
      bee = ['      \ /', '      (o>', '      / \\']
      flap = ['      / \\', '      (o>', '      \\ /']
      ground = '  ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~'
      scenes = []

      4.times do |i|
        sprite = i.even? ? bee : flap
        pad = ' ' * (2 + (i * 6))
        scenes << compose(
          '',
          pad + sprite[0],
          pad + sprite[1],
          pad + sprite[2],
          '',
          '',
          ground,
          center(''),
          center('')
        )
      end

      ['', '.', '|', '\\|/', '\\|/', '\\|/'].each_with_index do |plant, idx|
        sprite = idx.even? ? bee : flap
        pad = ' ' * 24
        title = if idx >= 4
                  'B U Z Z S P R O U T'
                elsif idx >= 2
                  'b u z z . . .'
                else
                  ''
                end
        tagline = idx >= 5 ? 'podcasts, take flight' : ''
        scenes << compose(
          '',
          pad + sprite[0],
          pad + sprite[1],
          pad + sprite[2],
          center(plant),
          '',
          ground,
          center(title),
          center(tagline)
        )
      end

      3.times do
        scenes << compose(
          '',
          (' ' * 24) + bee[0],
          (' ' * 24) + bee[1],
          (' ' * 24) + bee[2],
          center('\\|/'),
          '',
          ground,
          center('B U Z Z S P R O U T'),
          center('podcasts, take flight')
        )
      end

      scenes
    end

    def self.compose(*lines)
      lines.map { |line| line.to_s.ljust(WIDTH) }
    end

    def self.center(text)
      text.to_s.center(WIDTH)
    end

    private

    def skip?
      return false if @force
      return true unless @io.respond_to?(:tty?) && @io.tty?
      return true if ENV['BUZZSPROUT_NO_ANIMATION'] == '1'
      return true if ENV['CI']

      false
    end

    def colorize(frame)
      frame.map do |line|
        colored = line.dup
        colored.gsub!('B U Z Z S P R O U T', Color.cyan('B U Z Z S P R O U T', io: @io))
        colored.gsub!('podcasts, take flight', Color.dim('podcasts, take flight', io: @io))
        if Color.enabled?(@io)
          colored.gsub!('~', "#{Color::GREEN}~#{Color::RESET}")
          colored.gsub!('(o>', Color.yellow('(o>', io: @io))
          colored.gsub!('\\|/', Color.green('\\|/', io: @io))
        end
        colored
      end
    end
  end
end

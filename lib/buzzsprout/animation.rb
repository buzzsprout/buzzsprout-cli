# frozen_string_literal: true

require 'json'

# Terminal animation of the Default Buzzsprout wordmark (Figma 41:618).
# Frames are braille rasters of assets/logo; swap Light/Dark later by
# generating another frames.json — Default is source of truth for v0.

module Buzzsprout
  class Animation
    DEFAULT_DELAY = 0.055
    ASSET_DIR = File.expand_path('../../assets/logo', __dir__)
    FRAMES_FILE = File.join(ASSET_DIR, 'frames.json')

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
      delay = @delay || self.class.data['delay'] || DEFAULT_DELAY
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
      data.fetch('frames')
    end

    def self.width
      data.fetch('width')
    end

    def self.height
      data.fetch('height')
    end

    def self.data
      @data ||= JSON.parse(File.read(FRAMES_FILE))
    end

    def self.reset!
      @data = nil
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
      text_rows = frame['text']
      kind_rows = frame['kind']
      colors = self.class.data.fetch('colors', {})
      text_rows.each_with_index.map do |line, y|
        kinds = kind_rows[y].to_s
        next line unless Color.enabled?(@io)

        line.chars.each_with_index.map do |char, x|
          hex = colors[kinds[x]]
          hex ? Color.rgb(char, hex, io: @io) : char
        end.join
      end
    end
  end
end

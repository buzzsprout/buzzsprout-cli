# frozen_string_literal: true

module Buzzsprout
  module Color
    RESET   = "\e[0m"
    BOLD    = "\e[1m"
    DIM     = "\e[2m"
    RED     = "\e[31m"
    GREEN   = "\e[32m"
    YELLOW  = "\e[33m"
    BLUE    = "\e[34m"
    MAGENTA = "\e[35m"
    CYAN    = "\e[36m"

    module_function

    def enabled?(io = $stdout)
      return false if ENV['NO_COLOR']
      return false if ENV['BUZZSPROUT_NO_COLOR']

      io.respond_to?(:tty?) && io.tty?
    end

    def paint(text, *codes, io: $stdout)
      return text.to_s unless enabled?(io) && codes.any?

      "#{codes.join}#{text}#{RESET}"
    end

    def bold(text, io: $stdout)
      paint(text, BOLD, io: io)
    end

    def dim(text, io: $stdout)
      paint(text, DIM, io: io)
    end

    def red(text, io: $stdout)
      paint(text, RED, io: io)
    end

    def green(text, io: $stdout)
      paint(text, GREEN, io: io)
    end

    def yellow(text, io: $stdout)
      paint(text, YELLOW, io: io)
    end

    def cyan(text, io: $stdout)
      paint(text, CYAN, io: io)
    end

    def magenta(text, io: $stdout)
      paint(text, MAGENTA, io: io)
    end

    def rgb(text, hex, io: $stdout)
      value = hex.to_s.delete('#')
      r = value[0, 2].to_i(16)
      g = value[2, 2].to_i(16)
      b = value[4, 2].to_i(16)
      paint(text, "\e[38;2;#{r};#{g};#{b}m", io: io)
    end

    # :dark or :light. Override with BUZZSPROUT_THEME=dark|light.
    # Otherwise COLORFGBG, then an OSC 11 query on a TTY, then dark (readable
    # bright green). Skips OSC when CI=1 so tests and bots do not block.
    def theme(io = $stdout)
      @theme_cache ||= {}
      key = "#{ENV['BUZZSPROUT_THEME']}|#{ENV['COLORFGBG']}|#{io.object_id}"
      @theme_cache[key] ||= detect_theme(io)
    end

    def reset_theme!
      @theme_cache = {}
    end

    def detect_theme(io = $stdout)
      override = ENV['BUZZSPROUT_THEME'].to_s.strip.downcase
      return :dark if override == 'dark'
      return :light if override == 'light'

      from_colorfgbg || probe_osc11(io) || :dark
    end

    def from_colorfgbg
      raw = ENV['COLORFGBG'].to_s
      return nil if raw.empty?

      bg = raw.split(';').reverse.find { |part| part.match?(/\A\d+\z/) }
      return nil unless bg

      n = bg.to_i
      n == 7 || n >= 9 ? :light : :dark
    end

    # OSC 11 → rgb:RR/GG/BB. Luma > 0.5 is a light background.
    def parse_osc11(response)
      match = response.to_s.match(/rgb:([0-9a-fA-F]+)\/([0-9a-fA-F]+)\/([0-9a-fA-F]+)/)
      return nil unless match

      channels = match.captures.map do |hex|
        hex.to_i(16).to_f / ((16**hex.length) - 1)
      end
      luma = (0.2126 * channels[0]) + (0.7152 * channels[1]) + (0.0722 * channels[2])
      luma > 0.5 ? :light : :dark
    end

    def probe_osc11(io = $stdout)
      return nil if ENV['CI']
      return nil unless io.respond_to?(:tty?) && io.tty?
      return nil unless File.exist?('/dev/tty')

      File.open('/dev/tty', 'r+') do |tty|
        tty.write "\e]11;?\e\\"
        tty.flush
        buf = +''
        deadline = now + 0.08
        loop do
          left = deadline - now
          break if left <= 0

          ready, = IO.select([tty], nil, nil, left)
          break unless ready

          buf << tty.read_nonblock(256)
          break if buf.include?("\a") || buf.include?("\e\\")
        end
        parse_osc11(buf)
      end
    rescue Errno::ENXIO, Errno::ENOTTY, Errno::ENOENT, Errno::EAGAIN, Errno::EWOULDBLOCK, EOFError, IOError, ArgumentError
      nil
    end

    def now
      Process.clock_gettime(Process::CLOCK_MONOTONIC)
    end
  end
end

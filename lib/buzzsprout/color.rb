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
    # Otherwise COLORFGBG, then a best-effort OSC 11 query (raw TTY only),
    # then dark. OSC is skipped in CI and whenever it cannot be done without
    # leaking the reply as visible text.
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

    # Query the terminal background via OSC 11. Writes/reads only on +tty+
    # (never the UI stream). Requires raw/no-echo so the reply is not echoed.
    # Pass +tty:+ in tests. Returns nil if the probe cannot be done safely.
    def probe_osc11(ui_io = $stdout, tty: nil)
      injected = !tty.nil?
      return nil if ENV['CI'] && !injected

      tty ||= osc_console
      return nil unless osc_tty?(tty)
      return nil if tty.equal?(ui_io)

      reply = +''
      tty.raw do
        tty.write "\e]11;?\a"
        tty.flush if tty.respond_to?(:flush)
        reply = read_osc_reply(tty, timeout: 0.05)
        drain_tty(tty)
      end
      parse_osc11(reply)
    rescue Errno::ENXIO, Errno::ENOTTY, Errno::ENOENT, Errno::EAGAIN, Errno::EWOULDBLOCK, EOFError, IOError, ArgumentError
      nil
    end

    def osc_console
      require 'io/console'
      console = IO.console
      return nil unless console
      return nil unless console.respond_to?(:raw)
      return nil unless $stdin.respond_to?(:tty?) && $stdin.tty?

      console
    rescue LoadError
      nil
    end

    def osc_tty?(tty)
      tty &&
        tty.respond_to?(:tty?) && tty.tty? &&
        tty.respond_to?(:raw) &&
        tty.respond_to?(:write) &&
        tty.respond_to?(:read_nonblock)
    end

    def read_osc_reply(tty, timeout:)
      buf = +''
      deadline = monotonic + timeout
      loop do
        left = deadline - monotonic
        break if left <= 0

        chunk = read_tty_chunk(tty, left)
        break if chunk.nil?

        buf << chunk
        break if osc_reply_complete?(buf)
      end
      buf
    end

    def osc_reply_complete?(buf)
      buf.include?("\a") || buf.include?("\e\\")
    end

    def read_tty_chunk(tty, wait)
      tty.read_nonblock(256)
    rescue Errno::EAGAIN, Errno::EWOULDBLOCK, IO::WaitReadable
      return nil unless tty.respond_to?(:to_io) && tty.to_io

      ready, = IO.select([tty], nil, nil, wait)
      return nil unless ready

      retry
    end

    def drain_tty(tty)
      loop { tty.read_nonblock(4096) }
    rescue Errno::EAGAIN, Errno::EWOULDBLOCK, EOFError, IO::WaitReadable
      nil
    end

    def monotonic
      Process.clock_gettime(Process::CLOCK_MONOTONIC)
    end
  end
end

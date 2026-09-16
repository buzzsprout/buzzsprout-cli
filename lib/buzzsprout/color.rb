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
  end
end

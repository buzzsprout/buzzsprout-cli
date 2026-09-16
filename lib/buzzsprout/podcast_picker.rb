# frozen_string_literal: true

require 'io/console'
require_relative 'color'

module Buzzsprout
  # Interactive TTY selector for the authenticated user's podcasts.
  # Arrow keys move, typing filters by title/id, Enter selects, Esc/Ctrl-C cancels.
  class PodcastPicker
    class Cancelled < StandardError; end

    MISSING_ID = 'Podcast id required. Pass --podcast ID (or --in ID), or run `buzzsprout use`.'
    WINDOW = 12
    # Title, search line, hints. Reserve this plus WINDOW so redraws never scroll.
    CHROME = 3

    attr_reader :filter, :index, :podcasts

    def initialize(podcasts, io: $stdout, stdin: $stdin, default_id: nil)
      @podcasts = self.class.wrap_list(podcasts)
      @io = io
      @stdin = stdin
      @filter = +''
      @index = initial_index(default_id)
      @origin_saved = false
      @selected = nil
    end

    def self.wrap_list(data)
      rows = case data
             when Array then data
             when Hash then [data]
             else []
             end
      rows.map { |row| stringify(row) }
    end

    def self.interactive?(stdin:, json: false)
      return false if json
      return false if ENV['BUZZSPROUT_NONINTERACTIVE'] == '1'

      stdin.respond_to?(:tty?) && stdin.tty?
    end

    def self.choose!(podcasts, io: $stdout, stdin: $stdin, default_id: nil, auto_single: true)
      list = wrap_list(podcasts)
      raise 'No podcasts on this account. Create one in Buzzsprout, then retry.' if list.empty?
      return list.first if auto_single && list.size == 1

      new(list, io: io, stdin: stdin, default_id: default_id).select!
    end

    def filtered
      q = @filter.downcase
      return @podcasts if q.empty?

      @podcasts.select do |podcast|
        "#{podcast['id']} #{podcast['title']}".downcase.include?(q)
      end
    end

    def highlighted
      filtered[@index]
    end

    def handle_key(key)
      case key
      when :up
        move(-1)
      when :down
        move(1)
      when :enter
        item = highlighted
        return :empty if item.nil?

        @selected = item
        :selected
      when :esc, :ctrl_c
        :cancelled
      when :backspace
        @filter = @filter.chars[0...-1].join
        reindex_after_filter
      when :ctrl_u
        @filter = ''
        reindex_after_filter
      when String
        @filter += key
        reindex_after_filter
      end
    end

    def select!
      with_raw do
        loop do
          render
          result = handle_key(read_key)
          case result
          when :selected
            erase
            return @selected
          when :cancelled
            erase
            raise Cancelled, 'Podcast selection cancelled.'
          end
        end
      end
    ensure
      show_cursor
    end

    def build_lines
      items = filtered
      lines = []
      lines << Color.bold('Select a podcast', io: @io)
      lines << search_line
      if items.empty?
        lines << Color.dim('  (no matches)', io: @io)
      else
        window_start, visible = visible_slice(items)
        visible.each_with_index do |podcast, offset|
          active = (window_start + offset) == @index
          lines << format_row(podcast, active)
        end
      end
      lines << Color.dim('↑/↓ move  type to search  Enter select  Esc cancel', io: @io)
      lines
    end

    private

    def self.stringify(row)
      return { 'id' => nil, 'title' => nil } unless row.is_a?(Hash)

      {
        'id' => row['id'] || row[:id],
        'title' => row['title'] || row[:title]
      }
    end
    private_class_method :stringify

    def initial_index(default_id)
      return 0 if default_id.nil? || default_id.to_s.empty?

      found = @podcasts.index { |podcast| podcast['id'].to_s == default_id.to_s }
      found || 0
    end

    def move(delta)
      items = filtered
      return if items.empty?

      @index = (@index + delta) % items.size
    end

    def reindex_after_filter
      items = filtered
      @index = 0 if @index >= items.size || @index.negative?
    end

    def visible_slice(items)
      return [0, items] if items.size <= WINDOW

      start = @index - (WINDOW / 2)
      start = 0 if start.negative?
      max_start = items.size - WINDOW
      start = max_start if start > max_start
      [start, items[start, WINDOW]]
    end

    def format_row(podcast, active)
      label = "#{podcast['id']}  #{truncate(podcast['title'].to_s)}"
      if active
        Color.paint("▸ #{label}", Color::BOLD, highlight_code, io: @io)
      else
        "  #{label}"
      end
    end

    def highlight_code
      hex = Color.theme(@io) == :light ? '214538' : '61D752'
      r = hex[0, 2].to_i(16)
      g = hex[2, 2].to_i(16)
      b = hex[4, 2].to_i(16)
      "\e[38;2;#{r};#{g};#{b}m"
    end

    def search_line
      caret = Color.enabled?(@io) ? Color.paint('█', Color::DIM, io: @io) : '_'
      "Search: #{@filter}#{caret}"
    end

    def truncate(text, width = 64)
      return text if text.length <= width

      "#{text[0, width - 1]}…"
    end

    # Saved-cursor redraw (DECSC/DECRC + ED). CSI-A by logical line count
    # stair-steps when a row wraps or the screen scrolls.
    def render
      if @origin_saved
        @io.print "\e8\e[u\r"
      else
        height = WINDOW + CHROME
        height.times { @io.print "\n" }
        @io.print "\e[#{height}A\r\e7\e[s"
        @origin_saved = true
      end
      paint_lines(build_lines)
      @io.print "\e[0J"
      @io.flush if @io.respond_to?(:flush)
    end

    def paint_lines(lines)
      lines.each do |line|
        @io.print "\r\e[2K#{line}\e[0m\n"
      end
    end

    def erase
      return unless @origin_saved

      @io.print "\e8\e[u\e[0m\e[0J"
      @origin_saved = false
    end

    def with_raw
      hide_cursor
      if @stdin.respond_to?(:raw)
        @stdin.raw { yield }
      else
        yield
      end
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

    def read_key
      ch = read_char
      if ch.nil? || ch.empty?
        return :cancelled
      end

      case ch
      when "\u0003" then :ctrl_c
      when "\r", "\n" then :enter
      when "\u007f", "\b" then :backspace
      when "\u0015" then :ctrl_u
      when "\e" then read_escape
      else
        ch.match?(/[[:print:]]/) ? ch : nil
      end
    end

    def read_escape
      nxt = read_char_if_available
      return :esc if nxt.nil? || nxt.empty?

      if nxt == '[' || nxt == 'O'
        code = read_char_if_available
        return :up if code == 'A'
        return :down if code == 'B'
      end
      :esc
    end

    def read_char
      byte = read_byte
      return byte if byte.nil? || byte.empty?
      return byte if byte.bytesize != 1 || byte.ord < 0x80

      extra = case byte.ord
              when 0xC0..0xDF then 1
              when 0xE0..0xEF then 2
              when 0xF0..0xF7 then 3
              else 0
              end
      extra.times { byte += read_byte.to_s }
      byte.force_encoding(Encoding::UTF_8)
    end

    def read_char_if_available
      return read_char unless real_tty?

      ready, = IO.select([@stdin], nil, nil, 0.05)
      return nil unless ready

      read_char
    end

    def read_byte
      if @stdin.respond_to?(:getch) && real_tty?
        @stdin.getch
      elsif @stdin.eof?
        nil
      else
        @stdin.read(1)
      end
    rescue EOFError, IOError, Errno::EIO
      nil
    end

    def real_tty?
      @stdin.respond_to?(:to_io) && @stdin.to_io.is_a?(IO) && @stdin.respond_to?(:tty?) && @stdin.tty?
    rescue StandardError
      false
    end
  end
end

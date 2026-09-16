# frozen_string_literal: true

require_relative 'color'

module Buzzsprout
  # Basecamp-style group help for a parent command (USAGE / COMMANDS / FLAGS / …).
  class GroupHelp
    INHERITED_FLAGS = [
      ['--json', 'Print raw JSON'],
      ['--body \'{…}\'', 'JSON request body'],
      ['--file PATH', 'Upload a local file'],
      ['--podcast ID, --in ID', 'Podcast id for this invocation'],
      ['--dry-run', 'Print the request without sending it']
    ].freeze

    def initialize(io: $stdout)
      @io = io
    end

    def print(page)
      page = symbolize(page)
      summary = page[:summary].to_s
      @io.puts summary unless summary.empty?
      @io.puts '' unless summary.empty?

      section('USAGE', Array(page[:usage]))
      aliases = Array(page[:aliases])
      section('ALIASES', [aliases.join(', ')]) unless aliases.empty?
      section('COMMANDS', two_col(page[:commands])) if page[:commands]&.any?
      flags = Array(page[:flags]) + [['-h, --help', "Help for #{command_name(page)}"]]
      section('FLAGS', two_col(flags))
      section('INHERITED FLAGS', two_col(page[:inherited] || INHERITED_FLAGS))
      examples = Array(page[:examples])
      section('EXAMPLES', examples.map { |line| line.start_with?('$') ? line : "$ #{line}" }) unless examples.empty?
      learn = page[:learn] || "buzzsprout #{command_name(page)} --help"
      section('LEARN MORE', Array(learn))
    end

    def self.print(page, io: $stdout)
      new(io: io).print(page)
    end

    private

    def command_name(page)
      return page[:name] if page[:name]

      usage = Array(page[:usage]).first.to_s
      usage.split.find { |part| part != 'buzzsprout' } || 'command'
    end

    def section(title, lines)
      return if lines.nil? || lines.empty?

      @io.puts Color.bold(title, io: @io)
      lines.each { |line| @io.puts(line.match?(/\A\s/) ? line : "  #{line}") }
      @io.puts ''
    end

    def two_col(rows)
      rows = Array(rows)
      return [] if rows.empty?

      width = rows.map { |left, _| left.to_s.length }.max
      rows.map do |left, right|
        "  #{left.to_s.ljust(width)}  #{right}"
      end
    end

    def symbolize(page)
      page.to_h.transform_keys(&:to_sym)
    end
  end
end

# frozen_string_literal: true

require 'fileutils'

module Buzzsprout
  module Commands
    class Skills < Base
      USAGE = 'buzzsprout skills [command] [flags]'
      HELP_PAGE = {
        summary: 'Install and list agent skills shipped with the CLI.',
        usage: 'buzzsprout skills <command> [flags]',
        aliases: %w[skills],
        commands: [
          ['list', 'List bundled skills (default)'],
          ['path', 'Print the skills directory'],
          ['install', 'Copy skills into a local directory']
        ],
        flags: [
          ['--dir PATH', 'Install destination (default ~/.cursor/skills)']
        ],
        examples: [
          'buzzsprout skills',
          'buzzsprout skills install --dir ~/.cursor/skills'
        ]
      }.freeze

      def run
        verb = @args.shift || 'list'
        case verb
        when 'list' then list
        when 'path' then path
        when 'install' then install
        else
          group_help
        end
      end

      private

      def source_dir
        File.expand_path('../../../../skills', __FILE__)
      end

      def list
        skills = Dir.children(source_dir).sort.select { |name| File.directory?(File.join(source_dir, name)) }
        payload = { path: source_dir, skills: skills }
        output(payload) do
          @formatter.heading('Agent skills')
          @io.puts source_dir
          @io.puts ''
          skills.each { |name| @io.puts "  #{name}" }
          @io.puts ''
          @io.puts 'Install into a local skills directory:'
          @io.puts '  buzzsprout skills install'
          @io.puts '  buzzsprout skills install --dir ~/.cursor/skills'
        end
        0
      end

      def path
        @io.puts source_dir
        0
      end

      def install
        dest = Options.extract_option!(@args, '--dir') || File.expand_path('~/.cursor/skills')
        FileUtils.mkdir_p(dest)
        copied = []
        Dir.children(source_dir).sort.each do |name|
          src = File.join(source_dir, name)
          next unless File.directory?(src)

          target = File.join(dest, name)
          FileUtils.rm_rf(target)
          FileUtils.cp_r(src, target)
          copied << name
        end
        @io.puts "Installed #{copied.size} skills into #{dest}:"
        copied.each { |name| @io.puts "  #{name}" }
        0
      end
    end
  end
end

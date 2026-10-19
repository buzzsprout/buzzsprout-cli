# frozen_string_literal: true

require 'fileutils'

module Buzzsprout
  module Commands
    class Skills < Base
      USAGE = 'buzzsprout skills [command] [flags]'
      DEFAULT_DIR = File.expand_path('~/.cursor/skills')
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
          ['--dir PATH', 'Install destination (default ~/.cursor/skills or BUZZSPROUT_SKILLS_DIR)']
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

      def self.source_dir
        File.expand_path('../../../../skills', __FILE__)
      end

      def self.bundled_skill_names
        Dir.children(source_dir).sort.select { |name| File.directory?(File.join(source_dir, name)) }
      end

      def self.destination_dir(explicit = nil)
        explicit || ENV['BUZZSPROUT_SKILLS_DIR'] || DEFAULT_DIR
      end

      def self.installed?(dest = nil)
        dest = destination_dir(dest)
        names = bundled_skill_names
        return false if names.empty?

        names.all? { |name| File.file?(File.join(dest, name, 'SKILL.md')) }
      end

      def self.install_into!(dest, io: $stdout)
        dest = destination_dir(dest)
        FileUtils.mkdir_p(dest)
        copied = []
        bundled_skill_names.each do |name|
          src = File.join(source_dir, name)
          target = File.join(dest, name)
          FileUtils.rm_rf(target)
          FileUtils.cp_r(src, target)
          copied << name
        end
        io.puts "Installed #{copied.size} skills into #{dest}:"
        copied.each { |name| io.puts "  #{name}" }
        copied
      end

      private

      def source_dir
        self.class.source_dir
      end

      def list
        skills = self.class.bundled_skill_names
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
        dest = @options.dir || Options.extract_option!(@args, '--dir')
        self.class.install_into!(dest, io: @io)
        0
      end
    end
  end
end

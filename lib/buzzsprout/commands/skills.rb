# frozen_string_literal: true

require 'fileutils'
require 'securerandom'

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
          ['--dir PATH', 'Install destination (overrides detected Cursor/Claude Code directories)']
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

      def self.destination_dirs(explicit = nil, home: Dir.home)
        override = explicit || ENV['BUZZSPROUT_SKILLS_DIR']
        return [File.expand_path(override)] if override && !override.empty?

        %w[.cursor .claude].filter_map do |agent|
          root = File.join(home, agent)
          File.join(root, 'skills') if File.directory?(root)
        end
      end

      def self.installed_name(name)
        name == 'buzzsprout' ? name : "buzzsprout-#{name.tr('_', '-')}"
      end

      def self.skill_identity(path)
        return unless File.file?(path)
        File.read(path).match(/\A---\n.*?^name: ([^\n]+).*?^---$/m)&.captures&.first&.strip
      end

      def self.installed?(dest)
        bundled_skill_names.all? do |name|
          source = File.join(source_dir, name, 'SKILL.md')
          target = File.join(dest, installed_name(name), 'SKILL.md')
          File.file?(target) && File.binread(target) == File.binread(source)
        end
      end

      def self.install_into!(dest, io: $stdout)
        dest = File.expand_path(dest)
        names = bundled_skill_names
        names.each do |name|
          target = File.join(dest, installed_name(name))
          next unless File.exist?(target) || File.symlink?(target)
          expected = skill_identity(File.join(source_dir, name, 'SKILL.md'))
          unless !File.symlink?(target) && skill_identity(File.join(target, 'SKILL.md')) == expected
            raise "Refusing to replace unrelated or symlinked skill: #{target}"
          end
        end
        FileUtils.mkdir_p(dest)
        backup = File.join(File.dirname(dest), 'buzzsprout-skill-backups', "#{Time.now.utc.strftime('%Y%m%d%H%M%S')}-#{SecureRandom.hex(4)}")
        names.each do |name|
          src = File.join(source_dir, name)
          target = File.join(dest, installed_name(name))
          legacy = File.join(dest, name)
          candidates = [target]
          if legacy != target && !File.symlink?(legacy) && skill_identity(File.join(legacy, 'SKILL.md')) == skill_identity(File.join(src, 'SKILL.md'))
            candidates << legacy
          end
          candidates.each do |path|
            next unless File.exist?(path)
            FileUtils.mkdir_p(backup)
            FileUtils.mv(path, File.join(backup, File.basename(path)))
          end
          FileUtils.cp_r(src, target)
        end
        io.puts "Installed #{names.size} skills into #{dest}:"
        names.each { |name| io.puts "  #{installed_name(name)}" }
        io.puts "Previous skills saved in #{backup}" if File.directory?(backup)
        names
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
          @io.puts '  buzzsprout skills install --dir ~/.claude/skills'
        end
        0
      end

      def path
        @io.puts source_dir
        0
      end

      def install
        dest = @options.dir || Options.extract_option!(@args, '--dir')
        destinations = self.class.destination_dirs(dest)
        raise 'No supported agent directory found. Use --dir PATH to choose a skills directory.' if destinations.empty?
        destinations.each { |directory| self.class.install_into!(directory, io: @io) }
        0
      end
    end
  end
end

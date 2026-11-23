# frozen_string_literal: true

module Buzzsprout
  module Commands
    class Update < Base
      HELP_PAGE = {
        summary: 'Update a Git installation and refresh bundled agent skills.',
        usage: 'buzzsprout update [--check] [--json] [--dir PATH]',
        flags: [['--check', 'Check for updates without installing'], ['--json', 'Print machine-readable results'],
                ['--dir PATH', 'Skills destination override']],
        examples: ['buzzsprout update', 'buzzsprout update --check --json']
      }.freeze

      def run
        check_only = @args.delete('--check') || @options.dry_run?
        raise 'Unknown update arguments. Run buzzsprout update --help.' unless @args.empty?
        updater = Updater.new
        result = check_only ? updater.check : updater.update(io: @err, dir: @options.dir)
        output(result) do
          if check_only
            if result[:update_available]
              @io.puts "Update available. Run: #{result[:update_command]}"
              @io.puts 'Then run: buzzsprout skills install' unless result[:distribution].nil? || result[:distribution] == 'git'
            else
              @io.puts 'Buzzsprout CLI is up to date.'
            end
          else
            @io.puts(result[:updated] ? 'Buzzsprout CLI updated.' : 'Buzzsprout CLI is up to date.')
            @io.puts 'Start a new AI session to load refreshed skills.' if result[:skills_refreshed]
          end
        end
        0
      end
    end
  end
end

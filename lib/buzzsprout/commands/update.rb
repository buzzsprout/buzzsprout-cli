# frozen_string_literal: true

module Buzzsprout
  module Commands
    class Update < Base
      HELP_PAGE = {
        summary: 'Update the CLI and refresh bundled agent skills.',
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
            @io.puts(result[:update_available] ? 'Update available. Run: buzzsprout update' : 'Buzzsprout CLI is up to date.')
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

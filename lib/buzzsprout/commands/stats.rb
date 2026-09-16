# frozen_string_literal: true

module Buzzsprout
  module Commands
    class Stats < Base
      USAGE = 'buzzsprout stats [command] [flags]'
      HELP_WHEN_BARE = true
      HELP_PAGE = {
        summary: 'Show download stats for a podcast or episode.',
        usage: [
          'buzzsprout stats --date YYYY-MM-DD',
          'buzzsprout stats episode <episode_id> --date YYYY-MM-DD'
        ],
        aliases: %w[stats downloads],
        commands: [
          ['episode', 'Per-listener downloads for one episode']
        ],
        flags: [
          ['--date YYYY-MM-DD', 'Day to report (required)'],
          ['--page N', 'Page of episode downloads'],
          ['--per-page N', 'Page size of episode downloads']
        ],
        examples: [
          'buzzsprout stats --date 2026-09-16',
          'buzzsprout stats episode 788881 --date 2026-09-16'
        ]
      }.freeze

      def run
        if @args[0] == 'episode'
          @args.shift
          episode
        else
          podcast
        end
      end

      private

      def incomplete?
        @options.fields['date'].to_s.empty?
      end

      def podcast
        podcast_id = podcast_id_from_args!
        date = required_date
        data = client.get("/#{podcast_id}/downloads", query: { date: date })
        output(data) do
          @formatter.heading("Downloads for #{date}")
          Array(data).each { |row| @io.puts "episode #{row['episode_id']}: #{row['total']}" }
          @io.puts 'No downloads that day.' if Array(data).empty?
        end
        0
      end

      def episode
        podcast_id = podcast_id_from_args!
        episode_id = shift_id!('episode_id')
        date = required_date
        query = { date: date }
        query[:page] = @options.fields['page'] if @options.fields['page']
        query[:per_page] = @options.fields['per_page'] if @options.fields['per_page']
        data = client.get("/#{podcast_id}/#{episode_id}/downloads", query: query)
        output(data) do
          @formatter.heading("Episode #{episode_id} downloads for #{date}")
          rows = data.is_a?(Hash) ? data.dig('episodes', 0, 'downloads') : nil
          Array(rows).each do |row|
            @io.puts [row['app'], row['device'], row['city'], row['region'], row['country_code'], row['media_type']].compact.join('  •  ')
          end
        end
        0
      end

      def required_date
        date = @options.fields['date'] || Options.extract_option!(@args, '--date')
        raise 'date is required (--date YYYY-MM-DD)' if date.to_s.empty?

        date
      end
    end
  end
end

# frozen_string_literal: true

require 'date'

module Buzzsprout
  module Commands
    class Stats < Base
      USAGE = 'buzzsprout stats [command] [flags]'
      HELP_PAGE = {
        summary: 'Show download stats for a podcast or episode.',
        usage: [
          'buzzsprout stats [--date YYYY-MM-DD]',
          'buzzsprout stats episode <episode_id> [--date YYYY-MM-DD]'
        ],
        aliases: %w[stats downloads],
        commands: [
          ['episode', 'Per-listener downloads for one episode']
        ],
        flags: [
          ['--date YYYY-MM-DD', 'Day to report (default: today)'],
          ['--page N', 'Page of episode downloads'],
          ['--per-page N', 'Page size of episode downloads']
        ],
        examples: [
          'buzzsprout stats',
          'buzzsprout stats --date 2026-09-01',
          'buzzsprout stats episode 788881 --date 2026-09-01'
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

      def podcast
        podcast_id = podcast_id_from_args!
        date = report_date
        data = client.get("/#{podcast_id}/downloads", query: { date: date })
        output(data) do
          @formatter.heading("Downloads for #{date}")
          Array(data).each { |row| @io.puts "episode #{row['episode_id']}: #{row['total']}" }
          @io.puts 'No downloads that day.' if Array(data).empty?
        end
        0
      end

      def episode
        podcast_id = episode_podcast_id
        episode_id = shift_id!('episode_id')
        date = report_date
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

      def episode_podcast_id
        if @args.size >= 2 && !@args[0].to_s.start_with?('-') && !@args[1].to_s.start_with?('-')
          return @args.shift
        end

        explicit = @options.podcast_id || ENV['BUZZSPROUT_PODCAST_ID']
        return explicit unless explicit.to_s.empty?

        default = Config.saved_podcast_id
        return default if default

        if interactive_podcast_picker?
          chosen = pick_podcast!(announce: true)
          Config.save(default_podcast_id: chosen['id'])
          return chosen['id']
        end

        raise PodcastPicker::MISSING_ID
      end

      def report_date
        date = @options.fields['date'] || Options.extract_option!(@args, '--date')
        date = Date.today.strftime('%Y-%m-%d') if date.to_s.empty?
        date.to_s
      end
    end
  end
end

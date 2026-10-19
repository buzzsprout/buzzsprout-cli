# frozen_string_literal: true

require 'date'

module Buzzsprout
  module Commands
    class Downloads < Base
      USAGE = 'buzzsprout downloads today|yesterday|YYYY-MM-DD'
      HELP_WHEN_BARE = true
      DATE_TOKEN = /\A(\d{4}-\d{2}-\d{2}|today|yesterday)\z/i
      HELP_PAGE = {
        name: 'downloads',
        summary: 'Show download totals for one day (podcast or episode).',
        usage: [
          'buzzsprout downloads today|yesterday|YYYY-MM-DD',
          'buzzsprout episode <id> downloads today|yesterday|YYYY-MM-DD'
        ],
        aliases: %w[downloads stats],
        flags: [
          ['--date DATE', 'Alternate to a positional date (YYYY-MM-DD, today, yesterday)'],
          ['--page N', 'Page of episode downloads'],
          ['--per-page N', 'Page size of episode downloads']
        ],
        examples: [
          'buzzsprout downloads today',
          'buzzsprout downloads yesterday',
          'buzzsprout downloads 2026-09-01',
          'buzzsprout episode 788881 downloads today',
          'buzzsprout episode 788881 downloads yesterday',
          'buzzsprout episode 788881 downloads 2026-09-01'
        ]
      }.freeze

      attr_accessor :episode_id

      def run
        return group_help if misplaced_episode_subcommand?

        date = take_date!
        if episode_id
          show_episode(date)
        else
          show_podcast(date)
        end
      end

      private

      def incomplete?
        !date_present?
      end

      def misplaced_episode_subcommand?
        episode_id.nil? && @args[0] == 'episode'
      end

      def date_present?
        !flag_date.to_s.empty? || @args.any? { |arg| date_token?(arg) }
      end

      def flag_date
        @options.fields['date']
      end

      def date_token?(value)
        value.to_s.match?(DATE_TOKEN)
      end

      def take_date!
        token = flag_date.to_s.strip
        if token.empty?
          idx = @args.index { |arg| date_token?(arg) }
          token = @args.delete_at(idx).to_s if idx
        end
        resolve_date(token)
      end

      def resolve_date(token)
        value = token.to_s.strip
        raise 'date is required (today, yesterday, or YYYY-MM-DD)' if value.empty?

        case value.downcase
        when 'today' then Date.today.strftime('%Y-%m-%d')
        when 'yesterday' then (Date.today - 1).strftime('%Y-%m-%d')
        else value
        end
      end

      def show_podcast(date)
        podcast_id = podcast_id_from_args!
        data = client.get("/#{podcast_id}/downloads", query: { date: date })
        output(data) do
          @formatter.heading("Downloads for #{date}")
          Array(data).each { |row| @io.puts "episode #{row['episode_id']}: #{row['total']}" }
          @io.puts 'No downloads that day.' if Array(data).empty?
        end
        0
      end

      def show_episode(date)
        podcast_id = episode_podcast_id
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
        if @args.size >= 1 && !@args[0].to_s.start_with?('-') && !date_token?(@args[0])
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
    end

    Stats = Downloads
  end
end

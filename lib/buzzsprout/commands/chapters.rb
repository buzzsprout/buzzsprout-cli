# frozen_string_literal: true

module Buzzsprout
  module Commands
    class Chapters < Base
      USAGE = 'buzzsprout chapters <command> [flags]'
      HELP_WHEN_BARE = true
      HELP_PAGE = {
        summary: 'List or replace episode chapters.',
        usage: 'buzzsprout chapters <command> <episode_id>',
        aliases: %w[chapters],
        commands: [
          ['list', 'List chapters'],
          ['replace', 'Replace chapters (--body JSON)']
        ],
        examples: [
          'buzzsprout chapters list 788881',
          'buzzsprout chapters replace 788881 --body \'[{"title":"Intro","start_time":"00:00:00"}]\''
        ]
      }.freeze

      def run
        verb = @args.shift
        case verb
        when 'list' then list
        when 'replace', 'update' then replace
        else
          group_help
        end
      end

      private

      def list
        podcast_id = podcast_id_from_args!
        episode_id = shift_id!('episode_id')
        data = client.get("/#{podcast_id}/episodes/#{episode_id}/chapters")
        output(data) do
          @formatter.heading("Chapters for episode #{episode_id}")
          Array(data).each { |row| @io.puts "#{row['start_time']}  #{row['title']}  #{row['url']}" }
        end
        0
      end

      def replace
        podcast_id = podcast_id_from_args!
        episode_id = shift_id!('episode_id')
        body = @options.body
        raise 'Provide --body with a chapters array or {\"chapters\": [...]}' if body.nil?

        payload = body.is_a?(Array) ? { chapters: body } : body
        data = client.put("/#{podcast_id}/episodes/#{episode_id}/chapters", body: payload)
        output(data) { @io.puts "Replaced chapters on episode #{episode_id}" }
        0
      end
    end
  end
end

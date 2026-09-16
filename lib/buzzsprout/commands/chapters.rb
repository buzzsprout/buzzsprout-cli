# frozen_string_literal: true

module Buzzsprout
  module Commands
    class Chapters < Base
      USAGE = 'buzzsprout chapters <list|replace> <podcast_id> <episode_id> [--body JSON]'

      def run
        verb = @args.shift || 'list'
        case verb
        when 'list' then list
        when 'replace', 'update' then replace
        else
          raise USAGE
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

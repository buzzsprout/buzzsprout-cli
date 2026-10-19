# frozen_string_literal: true

module Buzzsprout
  module Commands
    class FeedVerifications < Base
      USAGE = 'buzzsprout feed-verifications [command] [flags]'
      HELP_PAGE = {
        summary: 'Manage podcast feed verification tags.',
        usage: 'buzzsprout feed-verifications <command> [id]',
        aliases: %w[feed-verifications feed_verifications],
        commands: [
          ['list', 'List verification tags (default)'],
          ['create', 'Create a tag (--value)'],
          ['update', 'Update a tag'],
          ['delete', 'Delete a tag']
        ],
        examples: [
          'buzzsprout feed-verifications',
          'buzzsprout feed-verifications create --value "abc123"'
        ]
      }.freeze

      def run
        verb = @args.shift || 'list'
        case verb
        when 'list' then list
        when 'create' then create
        when 'update' then update
        when 'delete' then delete
        else
          group_help
        end
      end

      private

      def list
        podcast_id = podcast_id_from_args!
        data = client.get("/#{podcast_id}/feed_verifications")
        output(data) do
          @formatter.heading("Feed verifications for podcast #{podcast_id}")
          Array(data).each { |row| @io.puts "#{row['id']}  #{row['purpose']}  #{row['value']}" }
        end
        0
      end

      def create
        podcast_id = podcast_id_from_args!
        body = @options.merge_body
        raise 'value is required' if body['value'].to_s.empty?

        data = client.post("/#{podcast_id}/feed_verifications", body: body)
        output(data) { @io.puts "Created feed verification #{data && data['id']}" }
        0
      end

      def update
        podcast_id = podcast_id_from_args!
        id = shift_id!('id')
        data = client.patch("/#{podcast_id}/feed_verifications/#{id}", body: @options.merge_body)
        output(data) { @io.puts "Updated feed verification #{id}" }
        0
      end

      def delete
        podcast_id = podcast_id_from_args!
        id = shift_id!('id')
        data = client.delete("/#{podcast_id}/feed_verifications/#{id}")
        output(data) { @io.puts "Deleted feed verification #{id}" }
        0
      end
    end
  end
end

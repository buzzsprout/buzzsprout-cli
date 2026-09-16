# frozen_string_literal: true

module Buzzsprout
  module Commands
    class Podrolls < Base
      USAGE = 'buzzsprout podrolls [command] [flags]'
      HELP_PAGE = {
        summary: 'Manage a podcast podroll.',
        usage: 'buzzsprout podrolls <command> [id]',
        aliases: %w[podrolls],
        commands: [
          ['list', 'List podroll entries (default)'],
          ['create', 'Create an entry (--guid, --feed-url)'],
          ['update', 'Update an entry'],
          ['delete', 'Delete an entry']
        ],
        examples: [
          'buzzsprout podrolls',
          'buzzsprout podrolls create --guid show-guid --feed-url https://example.com/feed.xml'
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
        data = client.get("/#{podcast_id}/podrolls")
        output(data) do
          @formatter.heading("Podrolls for podcast #{podcast_id}")
          Array(data).each { |row| @io.puts "#{row['id']}  pos #{row['position']}  #{row['feed_url']}" }
        end
        0
      end

      def create
        podcast_id = podcast_id_from_args!
        body = @options.merge_body
        raise 'guid and feed_url are required' if body['guid'].to_s.empty? || body['feed_url'].to_s.empty?

        data = client.post("/#{podcast_id}/podrolls", body: body)
        output(data) { @io.puts "Created podroll #{data && data['id']}" }
        0
      end

      def update
        podcast_id = podcast_id_from_args!
        id = shift_id!('id')
        data = client.patch("/#{podcast_id}/podrolls/#{id}", body: @options.merge_body)
        output(data) { @io.puts "Updated podroll #{id}" }
        0
      end

      def delete
        podcast_id = podcast_id_from_args!
        id = shift_id!('id')
        data = client.delete("/#{podcast_id}/podrolls/#{id}")
        output(data) { @io.puts "Deleted podroll #{id}" }
        0
      end
    end
  end
end

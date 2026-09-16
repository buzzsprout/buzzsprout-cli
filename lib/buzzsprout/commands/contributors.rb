# frozen_string_literal: true

module Buzzsprout
  module Commands
    class Contributors < Base
      USAGE = 'buzzsprout contributors <list|show|create|update|delete|assign|unassign> <podcast_id> [id]'

      def run
        dispatch(%w[list show create update delete assign unassign])
      end

      private

      def dispatch(verbs)
        verb = @args.shift || 'list'
        raise USAGE unless verbs.include?(verb)

        send(verb)
      end

      def list
        podcast_id = podcast_id_from_args!
        data = client.get("/#{podcast_id}/contributors")
        output(data) do
          @formatter.heading("Contributors for podcast #{podcast_id}")
          Array(data).each { |row| @io.puts "#{row['id']}  #{row['name']}  (#{row['role']})" }
        end
        0
      end

      def show
        podcast_id = podcast_id_from_args!
        id = shift_id!('contributor_id')
        data = client.get("/#{podcast_id}/contributors/#{id}")
        output(data) { @formatter.show_record("Contributor #{id}", data, %w[id name role bio url]) }
        0
      end

      def create
        podcast_id = podcast_id_from_args!
        body = @options.merge_body
        raise 'name is required' if body['name'].to_s.empty?

        data = client.post("/#{podcast_id}/contributors", body: body)
        output(data) { @io.puts "Created contributor #{data && data['id']}: #{data && data['name']}" }
        0
      end

      def update
        podcast_id = podcast_id_from_args!
        id = shift_id!('contributor_id')
        data = client.patch("/#{podcast_id}/contributors/#{id}", body: @options.merge_body)
        output(data) { @io.puts "Updated contributor #{id}" }
        0
      end

      def delete
        podcast_id = podcast_id_from_args!
        id = shift_id!('contributor_id')
        data = client.delete("/#{podcast_id}/contributors/#{id}")
        output(data) { @io.puts "Deleted contributor #{id}" }
        0
      end

      def assign
        podcast_id = podcast_id_from_args!
        episode_id = shift_id!('episode_id')
        contributor_id = @options.fields['contributor_id'] || shift_id!('contributor_id')
        data = client.post("/#{podcast_id}/episodes/#{episode_id}/contributors", body: { contributor_id: contributor_id })
        output(data) { @io.puts "Assigned contributor #{contributor_id} to episode #{episode_id}" }
        0
      end

      def unassign
        podcast_id = podcast_id_from_args!
        episode_id = shift_id!('episode_id')
        id = shift_id!('contributor_id')
        data = client.delete("/#{podcast_id}/episodes/#{episode_id}/contributors/#{id}")
        output(data) { @io.puts "Unassigned contributor #{id} from episode #{episode_id}" }
        0
      end
    end
  end
end

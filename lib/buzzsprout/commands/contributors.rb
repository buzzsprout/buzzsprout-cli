# frozen_string_literal: true

module Buzzsprout
  module Commands
    class Contributors < Base
      USAGE = 'buzzsprout contributors [command] [flags]'
      HELP_PAGE = {
        summary: 'Manage podcast contributors.',
        usage: 'buzzsprout contributors <command> [id]',
        aliases: %w[contributors],
        commands: [
          ['list', 'List contributors (default)'],
          ['show', 'Show one contributor'],
          ['create', 'Create a contributor (--name)'],
          ['update', 'Update a contributor'],
          ['delete', 'Delete a contributor'],
          ['assign', 'Assign a contributor to an episode'],
          ['unassign', 'Unassign a contributor from an episode']
        ],
        examples: [
          'buzzsprout contributors',
          'buzzsprout contributors create --name "Jane Doe" --role host --file ./headshot.jpg',
          'buzzsprout contributors update 123 --file ./headshot.png'
        ]
      }.freeze

      def run
        dispatch(%w[list show create update delete assign unassign])
      end

      private

      def dispatch(verbs)
        verb = @args.shift || 'list'
        return group_help unless verbs.include?(verb)

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
        output(data) { @formatter.show_record("Contributor #{id}", data, %w[id name role bio url headshot_url]) }
        0
      end

      def create
        podcast_id = podcast_id_from_args!
        body = @options.merge_body
        raise 'name is required' if body['name'].to_s.empty?

        data = write_contributor(:post, "/#{podcast_id}/contributors", body)
        output(data) { @io.puts "Created contributor #{data && data['id']}: #{data && data['name']}" }
        0
      end

      def update
        podcast_id = podcast_id_from_args!
        id = shift_id!('contributor_id')
        data = write_contributor(:patch, "/#{podcast_id}/contributors/#{id}", @options.merge_body)
        output(data) { @io.puts "Updated contributor #{id}" }
        0
      end

      def write_contributor(method, path, body)
        file = @options.file
        return client.public_send(method, path, body: body) if file.nil?

        raise 'Provide --file PATH' if file.empty?
        raise "File not found: #{file}" unless File.file?(file)

        content_type = { '.png' => 'image/png', '.jpg' => 'image/jpeg', '.jpeg' => 'image/jpeg', '.webp' => 'image/webp' }[File.extname(file).downcase]
        raise 'Headshot must be a PNG, JPEG, or WebP file' unless content_type

        parts = body.merge('headshot_file' => {
          filename: File.basename(file), content_type: content_type, data: File.binread(file)
        })
        client.public_send(method, path, multipart: parts)
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

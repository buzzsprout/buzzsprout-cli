# frozen_string_literal: true

module Buzzsprout
  module Commands
    class Team < Base
      USAGE = 'buzzsprout team [command] [flags]'
      HELP_PAGE = {
        summary: 'Manage podcast team members.',
        usage: 'buzzsprout team <command> [id]',
        aliases: %w[team],
        commands: [
          ['list', 'List team members (default)'],
          ['invite', 'Invite a member (--email, --role)'],
          ['update', 'Update a team member'],
          ['delete', 'Remove a team member']
        ],
        examples: [
          'buzzsprout team',
          'buzzsprout team invite --email editor@example.com --role editor'
        ]
      }.freeze

      def run
        verb = @args.shift || 'list'
        case verb
        when 'list' then list
        when 'invite', 'create' then invite
        when 'update' then update
        when 'delete', 'remove' then delete_member
        else
          group_help
        end
      end

      private

      def list
        podcast_id = podcast_id_from_args!
        data = client.get("/#{podcast_id}/team")
        output(data) do
          @formatter.heading("Team for podcast #{podcast_id}")
          Array(data).each { |row| @io.puts "#{row['id']}  #{row['name']}  #{row['email']}  (#{row['role']})" }
        end
        0
      end

      def invite
        podcast_id = podcast_id_from_args!
        body = @options.merge_body
        raise 'email is required' if body['email'].to_s.empty?

        data = client.post("/#{podcast_id}/team", body: body)
        output(data) { @io.puts "Invited #{data && data['email']} as #{data && data['role']}" }
        0
      end

      def update
        podcast_id = podcast_id_from_args!
        id = shift_id!('team_id')
        body = @options.merge_body
        data = client.patch("/#{podcast_id}/team/#{id}", body: body)
        output(data) { @io.puts "Updated team member #{id}" }
        0
      end

      def delete_member
        podcast_id = podcast_id_from_args!
        id = shift_id!('team_id')
        data = client.delete("/#{podcast_id}/team/#{id}")
        output(data) { @io.puts "Removed team member #{id}" }
        0
      end
    end
  end
end

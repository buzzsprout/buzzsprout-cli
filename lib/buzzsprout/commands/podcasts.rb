# frozen_string_literal: true

module Buzzsprout
  module Commands
    class Podcasts < Base
      USAGE = 'buzzsprout podcasts [command] [flags]'
      HELP_PAGE = {
        summary: 'List, show, update, and select Buzzsprout podcasts.',
        usage: 'buzzsprout podcasts <command> [flags]',
        aliases: %w[podcasts podcast],
        commands: [
          ['list', 'List podcasts (default)'],
          ['show <id>', 'Show podcast details'],
          ['update <id>', 'Update podcast metadata'],
          ['use [id]', 'Save a default podcast (picker if omitted)']
        ],
        examples: [
          'buzzsprout podcasts',
          'buzzsprout podcast use',
          'buzzsprout podcast use 10',
          'buzzsprout podcasts show 10'
        ]
      }.freeze

      def run
        verb, *rest = @args
        case verb
        when nil, 'list'
          list
        when 'show'
          @args.replace(rest)
          show
        when 'update'
          @args.replace(rest)
          update
        when 'use'
          @args.replace(rest)
          use_default
        when /\A\d+\z/
          @args.unshift(verb)
          show
        else
          group_help
        end
      end

      private

      def list
        podcasts = client.get('/podcasts')
        output(podcasts) { @formatter.list_podcasts(podcasts) }
        0
      end

      def show
        id = shift_id!('podcast_id')
        podcast = client.get("/podcasts/#{id}")
        output(podcast) do
          @formatter.show_record("Podcast #{podcast['id']}", podcast, %w[
            id title author description website_address website_url contact_email
            keywords explicit main_category sub_category language timezone
            artwork_url rss_url
          ])
        end
        0
      end

      def update
        id = shift_id!('podcast_id')
        body = @options.merge_body
        raise 'Provide fields to update (--title, --body JSON, …)' if body.empty?

        podcast = client.patch("/podcasts/#{id}", body: body)
        output(podcast) { @io.puts "Updated podcast #{id}: #{podcast && podcast['title']}" }
        0
      end

      def use_default
        id = resolve_podcast_id!(persist: true)
        @io.puts "Default podcast set to #{id}."
        0
      end
    end
  end
end

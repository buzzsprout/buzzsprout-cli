# frozen_string_literal: true

module Buzzsprout
  module Commands
    class Podcasts < Base
      USAGE = 'buzzsprout podcasts [list|show <id>|update <id>]'

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
        when /\A\d+\z/
          @args.unshift(verb)
          show
        else
          raise USAGE
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
    end
  end
end

# frozen_string_literal: true

module Buzzsprout
  module Commands
    class Episodes < Base
      USAGE = 'buzzsprout episodes [command] [flags]'
      HELP_PAGE = {
        summary: 'List and manage episodes for the current podcast.',
        usage: 'buzzsprout episodes <command> [podcast_id] [episode_id]',
        aliases: %w[episodes episode],
        commands: [
          ['list', 'List episodes (default)'],
          ['show', 'Show one episode'],
          ['create', 'Create an episode (--title)'],
          ['update', 'Update episode fields'],
          ['publish', 'Publish an episode'],
          ['unpublish', 'Unpublish (set private)']
        ],
        examples: [
          'buzzsprout episodes list',
          'buzzsprout episodes show 10 788881',
          'buzzsprout episodes create --title "Pilot" --private'
        ]
      }.freeze

      def run
        verb = @args.shift
        case verb
        when nil, 'list'
          list
        when 'show'
          show
        when 'create'
          create
        when 'update'
          update
        when 'publish'
          publish(false)
        when 'unpublish'
          publish(true)
        when /\A\d+\z/
          @args.unshift(verb)
          if @args[1] && @args[1] =~ /\A\d+\z/
            show
          else
            list
          end
        else
          group_help
        end
      end

      private

      def list
        podcast_id = podcast_id_from_args!
        episodes = client.get("/#{podcast_id}/episodes")
        output(episodes) do
          @formatter.heading("Episodes for podcast #{podcast_id}")
          Array(episodes).each do |episode|
            vis = episode['private'] ? 'private' : 'public'
            @io.puts "#{episode['id']}  #{episode['title']}  (#{vis}, plays: #{episode['total_plays']})"
          end
        end
        0
      end

      def show
        podcast_id = podcast_id_from_args!
        episode_id = shift_id!('episode_id')
        episode = client.get("/#{podcast_id}/episodes/#{episode_id}")
        output(episode) do
          @formatter.show_record("Episode #{episode['id']}", episode, %w[
            id title audio_url artwork_url description artist tags published_at
            duration guid custom_url episode_number season_number episode_type
            explicit private total_plays
          ])
        end
        0
      end

      def create
        podcast_id = podcast_id_from_args!
        body = @options.merge_body
        raise 'title is required (use --title or --body)' if body['title'].to_s.empty?

        episode = client.post("/#{podcast_id}/episodes", body: body)
        output(episode) { @io.puts "Created episode #{episode && episode['id']}: #{episode && episode['title']}" }
        0
      end

      def update
        podcast_id = podcast_id_from_args!
        episode_id = shift_id!('episode_id')
        body = @options.merge_body
        raise 'Provide fields to update (--title, --body JSON, …)' if body.empty?

        episode = client.patch("/#{podcast_id}/episodes/#{episode_id}", body: body)
        output(episode) { @io.puts "Updated episode #{episode_id}" }
        0
      end

      def publish(private_flag)
        podcast_id = podcast_id_from_args!
        episode_id = shift_id!('episode_id')
        body = @options.merge_body('private' => private_flag)
        episode = client.patch("/#{podcast_id}/episodes/#{episode_id}", body: body)
        verb = private_flag ? 'Unpublished' : 'Published'
        output(episode) { @io.puts "#{verb} episode #{episode_id}" }
        0
      end
    end
  end
end

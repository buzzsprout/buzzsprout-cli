# frozen_string_literal: true

module Buzzsprout
  module Commands
    class FanMail < Base
      USAGE = 'buzzsprout fan-mail <list|show|publish|unpublish|read|block> <podcast_id> [id]'

      def run
        verb = @args.shift || 'list'
        case verb
        when 'list' then list
        when 'show' then show
        when 'publish' then publish(true)
        when 'unpublish' then publish(false)
        when 'read' then read
        when 'block' then block
        else
          raise USAGE
        end
      end

      private

      def list
        podcast_id = podcast_id_from_args!
        data = client.get("/#{podcast_id}/fan_mail")
        output(data) do
          @formatter.heading("Fan mail for podcast #{podcast_id}")
          Array(data).each do |row|
            @io.puts "#{row['id']}  [#{row['status']}]  #{row['text'].to_s[0, 80]}"
          end
        end
        0
      end

      def show
        podcast_id = podcast_id_from_args!
        id = shift_id!('id')
        data = client.get("/#{podcast_id}/fan_mail/#{id}")
        output(data) { @formatter.show_record("Fan mail #{id}", data, %w[id status published blocked text sender_info city state country created_at message_type]) }
        0
      end

      def publish(flag)
        podcast_id = podcast_id_from_args!
        id = shift_id!('id')
        data = client.patch("/#{podcast_id}/fan_mail/#{id}", body: { published: flag })
        output(data) { @io.puts "#{flag ? 'Published' : 'Unpublished'} fan mail #{id}" }
        0
      end

      def read
        podcast_id = podcast_id_from_args!
        id = shift_id!('id')
        data = client.post("/#{podcast_id}/fan_mail/#{id}/read")
        output(data) { @io.puts "Marked fan mail #{id} as read" }
        0
      end

      def block
        podcast_id = podcast_id_from_args!
        id = shift_id!('id')
        data = client.post("/#{podcast_id}/fan_mail/#{id}/block")
        output(data) { @io.puts "Blocked sender for fan mail #{id}" }
        0
      end
    end

    class InsertionPoints < Base
      USAGE = 'buzzsprout insertion-points <list|create|update|delete> <podcast_id> <episode_id> [id]'

      def run
        verb = @args.shift || 'list'
        case verb
        when 'list' then list
        when 'create' then create
        when 'update' then update
        when 'delete' then delete
        else
          raise USAGE
        end
      end

      private

      def list
        podcast_id = podcast_id_from_args!
        episode_id = shift_id!('episode_id')
        data = client.get("/#{podcast_id}/episodes/#{episode_id}/insertion_points")
        output(data) do
          @formatter.heading("Insertion points for episode #{episode_id}")
          Array(data).each { |row| @io.puts "#{row['id']}  #{row['timestamp']} (#{row['seconds']}s)  eligible=#{row['eligible']}" }
        end
        0
      end

      def create
        podcast_id = podcast_id_from_args!
        episode_id = shift_id!('episode_id')
        body = @options.merge_body
        raise 'Provide --timestamp or --seconds' if body['timestamp'].nil? && body['seconds'].nil?

        data = client.post("/#{podcast_id}/episodes/#{episode_id}/insertion_points", body: body)
        output(data) { @io.puts "Created insertion point #{data && data['id']}" }
        0
      end

      def update
        podcast_id = podcast_id_from_args!
        episode_id = shift_id!('episode_id')
        id = shift_id!('id')
        data = client.patch("/#{podcast_id}/episodes/#{episode_id}/insertion_points/#{id}", body: @options.merge_body)
        output(data) { @io.puts "Updated insertion point #{id}" }
        0
      end

      def delete
        podcast_id = podcast_id_from_args!
        episode_id = shift_id!('episode_id')
        id = shift_id!('id')
        data = client.delete("/#{podcast_id}/episodes/#{episode_id}/insertion_points/#{id}")
        output(data) { @io.puts "Deleted insertion point #{id}" }
        0
      end
    end

    class Soundbites < Base
      USAGE = 'buzzsprout soundbites <show|create|delete> <podcast_id> <episode_id>'

      def run
        verb = @args.shift || 'show'
        case verb
        when 'show' then show
        when 'create' then create
        when 'delete' then delete
        else
          raise USAGE
        end
      end

      private

      def show
        podcast_id = podcast_id_from_args!
        episode_id = shift_id!('episode_id')
        data = client.get("/#{podcast_id}/episodes/#{episode_id}/soundbite")
        output(data) { @formatter.show_record("Soundbite for episode #{episode_id}", data, %w[id creating_video start_time duration aspect_ratio artwork]) }
        0
      end

      def create
        podcast_id = podcast_id_from_args!
        episode_id = shift_id!('episode_id')
        data = client.post("/#{podcast_id}/episodes/#{episode_id}/soundbite", body: @options.merge_body)
        output(data) { @io.puts "Started soundbite #{data && data['id']} (creating_video=#{data && data['creating_video']})" }
        0
      end

      def delete
        podcast_id = podcast_id_from_args!
        episode_id = shift_id!('episode_id')
        data = client.delete("/#{podcast_id}/episodes/#{episode_id}/soundbite")
        output(data) { @io.puts "Deleted soundbite for episode #{episode_id}" }
        0
      end
    end
  end
end

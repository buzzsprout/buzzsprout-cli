# frozen_string_literal: true

module Buzzsprout
  module Commands
    class Listings < Base
      USAGE = 'buzzsprout listings <list|submit-all> <podcast_id>'

      def run
        verb = @args.shift || 'list'
        case verb
        when 'list' then list
        when 'submit-all', 'submit_all', 'submit' then submit_all
        else
          raise USAGE
        end
      end

      private

      def list
        podcast_id = podcast_id_from_args!
        data = client.get("/#{podcast_id}/listings")
        output(data) do
          @formatter.heading("Listings for podcast #{podcast_id}")
          Array(data).each { |row| @io.puts "#{row['directory']}  #{row['status']}  #{row['url']}" }
        end
        0
      end

      def submit_all
        podcast_id = podcast_id_from_args!
        data = client.post("/#{podcast_id}/listings/submit_all")
        output(data) { @io.puts "Submitted remaining one-click directories for podcast #{podcast_id}" }
        0
      end
    end

    class Podrolls < Base
      USAGE = 'buzzsprout podrolls <list|create|update|delete> <podcast_id> [id]'

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

    class FeedVerifications < Base
      USAGE = 'buzzsprout feed-verifications <list|create|update|delete> <podcast_id> [id]'

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

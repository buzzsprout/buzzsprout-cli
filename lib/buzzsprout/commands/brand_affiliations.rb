# frozen_string_literal: true

module Buzzsprout
  module Commands
    class BrandAffiliations < Base
      USAGE = 'buzzsprout brand-affiliations <list|show|create|update|delete|assign|unassign> <podcast_id> [id]'

      def run
        verb = @args.shift || 'list'
        raise USAGE unless %w[list show create update delete assign unassign].include?(verb)

        send(verb)
      end

      private

      def list
        podcast_id = podcast_id_from_args!
        data = client.get("/#{podcast_id}/brand_affiliations")
        output(data) do
          @formatter.heading("Brand affiliations for podcast #{podcast_id}")
          Array(data).each { |row| @io.puts "#{row['id']}  #{row['headline']}  #{row['url']}" }
        end
        0
      end

      def show
        podcast_id = podcast_id_from_args!
        id = shift_id!('id')
        data = client.get("/#{podcast_id}/brand_affiliations/#{id}")
        output(data) { @formatter.show_record("Brand affiliation #{id}", data, %w[id headline description url artwork_url]) }
        0
      end

      def create
        podcast_id = podcast_id_from_args!
        body = @options.merge_body
        raise 'headline is required' if body['headline'].to_s.empty?

        data = client.post("/#{podcast_id}/brand_affiliations", body: body)
        output(data) { @io.puts "Created brand affiliation #{data && data['id']}" }
        0
      end

      def update
        podcast_id = podcast_id_from_args!
        id = shift_id!('id')
        data = client.patch("/#{podcast_id}/brand_affiliations/#{id}", body: @options.merge_body)
        output(data) { @io.puts "Updated brand affiliation #{id}" }
        0
      end

      def delete
        podcast_id = podcast_id_from_args!
        id = shift_id!('id')
        data = client.delete("/#{podcast_id}/brand_affiliations/#{id}")
        output(data) { @io.puts "Deleted brand affiliation #{id}" }
        0
      end

      def assign
        podcast_id = podcast_id_from_args!
        episode_id = shift_id!('episode_id')
        brand_id = @options.fields['brand_affiliation_id'] || shift_id!('brand_affiliation_id')
        data = client.post("/#{podcast_id}/episodes/#{episode_id}/brand_affiliations", body: { brand_affiliation_id: brand_id })
        output(data) { @io.puts "Assigned brand affiliation #{brand_id} to episode #{episode_id}" }
        0
      end

      def unassign
        podcast_id = podcast_id_from_args!
        episode_id = shift_id!('episode_id')
        id = shift_id!('id')
        data = client.delete("/#{podcast_id}/episodes/#{episode_id}/brand_affiliations/#{id}")
        output(data) { @io.puts "Unassigned brand affiliation #{id} from episode #{episode_id}" }
        0
      end
    end
  end
end

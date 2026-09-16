# frozen_string_literal: true

module Buzzsprout
  module Commands
    class Transcripts < Base
      USAGE = 'buzzsprout transcripts <show|upload|delete|high-fidelity|replace-high-fidelity> <podcast_id> <episode_id>'

      def run
        verb = @args.shift || 'show'
        case verb
        when 'show' then show
        when 'upload', 'create' then upload
        when 'delete' then delete
        when 'high-fidelity', 'hf' then high_fidelity
        when 'replace-high-fidelity', 'replace-hf' then replace_high_fidelity
        else
          raise USAGE
        end
      end

      private

      def show
        podcast_id = podcast_id_from_args!
        episode_id = shift_id!('episode_id')
        data = client.get("/#{podcast_id}/episodes/#{episode_id}/transcript")
        output(data) { @formatter.show_record("Transcript for episode #{episode_id}", data, %w[id status published download_url]) }
        0
      end

      def upload
        podcast_id = podcast_id_from_args!
        episode_id = shift_id!('episode_id')
        path = @options.file
        raise 'Provide --file PATH' if path.to_s.empty?
        raise "File not found: #{path}" unless File.file?(path)

        format = @options.fields['transcript_format'] || @options.format || File.extname(path).delete_prefix('.').downcase
        raise 'transcript format must be srt or json' unless %w[srt json].include?(format)

        data = client.post(
          "/#{podcast_id}/episodes/#{episode_id}/transcript",
          multipart: {
            transcript_file: {
              filename: File.basename(path),
              content_type: format == 'json' ? 'application/json' : 'application/x-subrip',
              data: File.binread(path)
            },
            transcript_format: format
          }
        )
        output(data) { @io.puts "Uploaded custom transcript for episode #{episode_id}" }
        0
      end

      def delete
        podcast_id = podcast_id_from_args!
        episode_id = shift_id!('episode_id')
        data = client.delete("/#{podcast_id}/episodes/#{episode_id}/transcript")
        output(data) { @io.puts "Deleted custom transcript for episode #{episode_id}" }
        0
      end

      def high_fidelity
        podcast_id = podcast_id_from_args!
        episode_id = shift_id!('episode_id')
        data = client.get("/#{podcast_id}/episodes/#{episode_id}/high_fidelity_transcript")
        output(data) { @io.puts "High-fidelity transcript: #{Array(data).size} segments" }
        0
      end

      def replace_high_fidelity
        podcast_id = podcast_id_from_args!
        episode_id = shift_id!('episode_id')
        raise 'Provide --body with a segment array' unless @options.body.is_a?(Array)

        data = client.put("/#{podcast_id}/episodes/#{episode_id}/high_fidelity_transcript", body: @options.body)
        output(data) { @io.puts "Replaced high-fidelity transcript for episode #{episode_id}" }
        0
      end
    end
  end
end

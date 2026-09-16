# frozen_string_literal: true

module Buzzsprout
  module Commands
    class Uploads < Base
      USAGE = 'buzzsprout uploads <command> [flags]'
      HELP_WHEN_BARE = true
      HELP_PAGE = {
        summary: 'Upload audio or video for an episode.',
        usage: 'buzzsprout uploads <command> <episode_id> [upload_id]',
        aliases: %w[uploads upload],
        commands: [
          ['start', 'Start an upload (--file PATH)'],
          ['complete', 'Mark an upload complete'],
          ['abort', 'Abort an in-progress upload']
        ],
        flags: [
          ['--file PATH', 'Local media file (start)']
        ],
        examples: [
          'buzzsprout uploads start 788881 --file ./episode.m4a',
          'buzzsprout uploads complete 788881 UPLOAD_ID'
        ]
      }.freeze

      MIME = {
        'mp3' => 'audio/mpeg',
        'm4a' => 'audio/mp4',
        'aac' => 'audio/aac',
        'wav' => 'audio/wav',
        'ogg' => 'audio/ogg',
        'flac' => 'audio/flac',
        'mp4' => 'video/mp4',
        'm4v' => 'video/mp4',
        'mov' => 'video/quicktime',
        'webm' => 'video/webm'
      }.freeze

      def run
        verb = @args.shift
        case verb
        when 'start', 'upload'
          start
        when 'complete'
          complete
        when 'abort'
          abort_upload
        else
          group_help
        end
      end

      private

      def start
        podcast_id = podcast_id_from_args!
        episode_id = shift_id!('episode_id')
        path = @options.file || Options.extract_option!(@args, '--file')
        raise 'Provide --file PATH' if path.to_s.empty?
        raise "File not found: #{path}" unless File.file?(path)

        size = File.size(path)
        filename = File.basename(path)
        type = @options.fields['type'] || mime_for(filename)
        multipart = @options.fields.key?('multipart') ? @options.fields['multipart'] : (size > 5 * 1024 * 1024 * 1024)
        body = {
          filename: filename,
          type: type,
          byte_size: size
        }
        body[:multipart] = true if multipart

        started = client.post("/#{podcast_id}/episodes/#{episode_id}/uploads", body: body)
        return 0 if started.nil? && @options.dry_run?

        upload = started.is_a?(Hash) ? (started['upload'] || started) : started
        output(started) { @io.puts "Started upload #{upload['id']} (#{filename}, #{size} bytes)" }

        if upload['multipart']
          put_parts(path, upload)
        else
          url = upload['upload_url']
          raise 'No upload_url returned' if url.to_s.empty?

          bytes = File.binread(path)
          @io.puts "Uploading bytes to storage (no Authorization header)…"
          client.put_bytes(url, bytes)
        end

        upload_id = encode_id(upload['id'])
        completed = client.post("/#{podcast_id}/episodes/#{episode_id}/uploads/#{upload_id}/complete")
        output(completed) { @io.puts Color.green("Upload complete. Encoding will finish asynchronously — poll with: buzzsprout episodes show #{podcast_id} #{episode_id}", io: @io) }
        0
      end

      def complete
        podcast_id = podcast_id_from_args!
        episode_id = shift_id!('episode_id')
        upload_id = encode_id(shift_id!('upload_id'))
        result = client.post("/#{podcast_id}/episodes/#{episode_id}/uploads/#{upload_id}/complete")
        output(result) { @io.puts "Completed upload #{upload_id}" }
        0
      end

      def abort_upload
        podcast_id = podcast_id_from_args!
        episode_id = shift_id!('episode_id')
        upload_id = encode_id(shift_id!('upload_id'))
        result = client.delete("/#{podcast_id}/episodes/#{episode_id}/uploads/#{upload_id}/abort")
        output(result) { @io.puts "Aborted upload #{upload_id}" }
        0
      end

      def put_parts(path, upload)
        part_size = upload['part_size'].to_i
        File.open(path, 'rb') do |file|
          Array(upload['parts']).each do |part|
            length = part.fetch('content_length').to_i
            offset = (part.fetch('part_number').to_i - 1) * part_size
            file.seek(offset)
            bytes = file.read(length)
            @io.puts "Uploading part #{part['part_number']} (#{length} bytes)…"
            client.put_bytes(part.fetch('url'), bytes)
          end
        end
      end

      def mime_for(filename)
        ext = File.extname(filename).delete_prefix('.').downcase
        MIME[ext] || 'application/octet-stream'
      end
    end
  end
end

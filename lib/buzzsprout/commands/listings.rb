# frozen_string_literal: true

module Buzzsprout
  module Commands
    class Listings < Base
      USAGE = 'buzzsprout listings [directory] [url|status]'
      HELP_PAGE = {
        summary: 'Directory listings for a podcast.',
        usage: [
          'buzzsprout listings',
          'buzzsprout listings <directory> [url|status]',
          'buzzsprout listings submit-all'
        ],
        aliases: %w[listings],
        commands: [
          ['list', 'List all directories (default)'],
          ['<directory>', 'One directory: name, status, and url'],
          ['<directory> url', "Print that directory's URL"],
          ['<directory> status', 'Print listed / submitted / unlisted / failed'],
          ['submit-all', 'Submit remaining one-click directories']
        ],
        examples: [
          'buzzsprout listings',
          'buzzsprout listings Apple url',
          'buzzsprout listings Apple status',
          'buzzsprout listings Spotify',
          'buzzsprout listings submit-all'
        ]
      }.freeze
      FIELD_TOKENS = %w[url status].freeze

      def run
        case @args[0]
        when nil, 'list'
          @args.shift if @args[0] == 'list'
          list
        when 'submit-all', 'submit_all', 'submit'
          @args.shift
          submit_all
        else
          show_directory
        end
      end

      private

      def list
        list_for(listing_podcast_id!)
      end

      def show_directory
        field = take_field!
        podcast_id = listing_podcast_id!
        query = @args.join(' ').strip
        if query.empty?
          raise 'Missing directory. Example: buzzsprout listings Apple url' if field

          return list_for(podcast_id)
        end

        data = client.get("/#{podcast_id}/listings")
        listing = find_listing!(Array(data), query)
        output(listing) do
          if field
            @io.puts listing[field].to_s
          else
            @io.puts compact_listing(listing)
          end
        end
        0
      end

      def list_for(podcast_id)
        data = client.get("/#{podcast_id}/listings")
        output(data) do
          @formatter.heading("Listings for podcast #{podcast_id}")
          Array(data).each { |row| @io.puts "#{row['directory']}  #{row['status']}  #{row['url']}" }
        end
        0
      end

      def submit_all
        podcast_id = listing_podcast_id!
        data = client.post("/#{podcast_id}/listings/submit_all")
        output(data) { @io.puts "Submitted remaining one-click directories for podcast #{podcast_id}" }
        0
      end

      def take_field!
        token = @args.last.to_s
        return unless FIELD_TOKENS.include?(token.downcase)

        @args.pop.downcase
      end

      def listing_podcast_id!
        if @args[0].to_s.match?(/\A\d+\z/)
          return @args.shift
        end

        explicit = @options.podcast_id || ENV['BUZZSPROUT_PODCAST_ID']
        return explicit unless explicit.to_s.empty?

        default = Config.saved_podcast_id
        return default if default

        if interactive_podcast_picker?
          chosen = pick_podcast!(announce: true)
          Config.save(default_podcast_id: chosen['id'])
          return chosen['id']
        end

        raise PodcastPicker::MISSING_ID
      end

      def find_listing!(rows, query)
        needle = query.downcase
        exact_dir = rows.select { |row| row['directory'].to_s.downcase == needle }
        return unique_listing!(exact_dir, query) if exact_dir.any?

        exact_name = rows.select { |row| row['name'].to_s.downcase == needle }
        return unique_listing!(exact_name, query) if exact_name.any?

        prefix = rows.select do |row|
          row['directory'].to_s.downcase.start_with?(needle) ||
            row['name'].to_s.downcase.start_with?(needle)
        end
        return unique_listing!(prefix, query) if prefix.any?

        substr = rows.select do |row|
          row['directory'].to_s.downcase.include?(needle) ||
            row['name'].to_s.downcase.include?(needle)
        end
        return unique_listing!(substr, query) if substr.any?

        raise "No listing matched #{query.inspect}."
      end

      def unique_listing!(rows, query)
        return rows.first if rows.size == 1

        labels = rows.map { |row| listing_label(row) }.uniq
        raise "Multiple listings match #{query.inspect}: #{labels.join(', ')}. Be more specific."
      end

      def listing_label(row)
        dir = row['directory'].to_s
        name = row['name'].to_s
        return dir if name.empty? || name == dir

        "#{dir} (#{name})"
      end

      def compact_listing(row)
        [row['name'] || row['directory'], row['status'], row['url']].compact.join('  ')
      end
    end
  end
end

# frozen_string_literal: true

require 'uri'
require_relative '../podcast_picker'

module Buzzsprout
  module Commands
    class Base
      def initialize(args, options, io: $stdout, err: $stderr, stdin: $stdin)
        @args = args
        @options = options
        @io = io
        @err = err
        @stdin = stdin
        @formatter = Formatter.new(io: io)
      end

      private

      def client
        @client ||= Client.new(
          token: Config.require_token!,
          dry_run: @options.dry_run?,
          io: @err
        )
      end

      def output(data)
        return if @options.dry_run? && data.nil?

        if @options.json?
          @formatter.json(data)
        elsif block_given?
          yield data
        else
          @formatter.json(data)
        end
      end

      def shift_id!(label)
        value = @args.shift
        raise "Missing #{label}. #{usage_line}" if value.nil? || value.start_with?('-')

        value
      end

      def podcast_id_from_args!
        resolve_podcast_id!
      end

      # 1. Explicit positional / --podcast / --in / BUZZSPROUT_PODCAST_ID
      # 2. Interactive picker on a TTY (saved default only pre-highlights)
      # 3. Noninteractive: saved default, else a clear error (never blocks)
      def resolve_podcast_id!(persist: false)
        explicit = take_explicit_podcast_id
        if explicit
          Config.save(default_podcast_id: explicit) if persist
          return explicit
        end

        if interactive_podcast_picker?
          chosen = pick_podcast!(announce: !persist)
        else
          chosen = noninteractive_podcast
        end

        Config.save(default_podcast_id: chosen['id']) if persist
        chosen['id']
      end

      def interactive_podcast_picker?
        PodcastPicker.interactive?(stdin: @stdin, json: @options.json?)
      end

      def pick_podcast!(announce: true)
        podcasts = fetch_podcasts
        if podcasts.size == 1
          chosen = podcasts.first
          announce_podcast(chosen) if announce
          return chosen
        end

        chosen = PodcastPicker.choose!(
          podcasts,
          io: @io,
          stdin: @stdin,
          default_id: Config.default_podcast_id,
          auto_single: false
        )
        announce_podcast(chosen) if announce
        chosen
      end

      def noninteractive_podcast
        default = Config.default_podcast_id
        if default && !default.to_s.empty?
          return { 'id' => default, 'title' => nil }
        end

        raise PodcastPicker::MISSING_ID
      end

      def take_explicit_podcast_id
        from_args = @args.first
        if from_args && !from_args.start_with?('-')
          return @args.shift
        end

        value = @options.podcast_id || ENV['BUZZSPROUT_PODCAST_ID']
        return if value.nil? || value.to_s.empty?

        value
      end

      def fetch_podcasts
        PodcastPicker.wrap_list(client.get('/podcasts'))
      end

      def announce_podcast(podcast)
        return if @options.json?

        title = podcast['title']
        label = title.to_s.empty? ? podcast['id'].to_s : "#{podcast['id']}  #{title}"
        @io.puts Color.dim("Using podcast #{label}", io: @io)
      end

      def usage_line
        self.class.const_defined?(:USAGE) ? self.class::USAGE : ''
      end

      def encode_id(value)
        URI.encode_www_form_component(value.to_s)
      end

      def confirm_empty_delete
        true
      end
    end
  end
end

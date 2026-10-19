# frozen_string_literal: true

require 'uri'
require_relative '../podcast_picker'
require_relative '../group_help'

module Buzzsprout
  module Commands
    module GroupHelpHook
      def run
        return group_help if take_help_flag! || show_bare_help?

        super
      end
    end

    class Base
      def self.inherited(klass)
        super
        klass.prepend(GroupHelpHook)
      end

      def initialize(args, options, io: $stdout, err: $stderr, stdin: $stdin)
        @args = args
        @options = options
        @io = io
        @err = err
        @stdin = stdin
        @formatter = Formatter.new(io: io)
      end

      private

      def take_help_flag!
        removed = false
        @args.delete_if do |arg|
          next false unless %w[-h --help].include?(arg)

          removed = true
          true
        end
        removed
      end

      def show_bare_help?
        return false unless self.class.const_defined?(:HELP_WHEN_BARE) && self.class::HELP_WHEN_BARE

        incomplete?
      end

      def incomplete?
        @args.empty?
      end

      def group_help
        GroupHelp.print(help_page, io: @io)
        0
      end

      def help_page
        page = self.class.const_defined?(:HELP_PAGE) ? self.class::HELP_PAGE.dup : {}
        page[:usage] ||= usage_line
        page[:name] ||= usage_line.to_s.split[1]
        page
      end

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
      # 2. Saved default (skip picker) unless persist:true (`buzzsprout podcast use`)
      # 3. Interactive picker on a TTY, then save as default
      # 4. Noninteractive: saved default, else a clear error (never blocks)
      def resolve_podcast_id!(persist: false)
        explicit = take_explicit_podcast_id
        if explicit
          Config.save(default_podcast_id: explicit) if persist
          return explicit
        end

        unless persist
          default = Config.saved_podcast_id
          return default if default
        end

        if interactive_podcast_picker?
          chosen = pick_podcast!(announce: !persist)
          Config.save(default_podcast_id: chosen['id'])
          return chosen['id']
        end

        default = Config.saved_podcast_id
        return default if default

        raise PodcastPicker::MISSING_ID
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
          default_id: Config.saved_podcast_id,
          auto_single: false
        )
        announce_podcast(chosen) if announce
        chosen
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

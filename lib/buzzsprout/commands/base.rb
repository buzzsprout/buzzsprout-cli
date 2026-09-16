# frozen_string_literal: true

require 'uri'

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
        value = @args.shift || @options.podcast_id || Config.default_podcast_id
        raise "Podcast id required. #{usage_line}" if value.nil? || value.to_s.empty?

        value
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

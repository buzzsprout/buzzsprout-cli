# frozen_string_literal: true

require 'json'

module Buzzsprout
  class Options
    attr_reader :json, :no_animation, :dry_run, :token, :podcast_id, :body, :file, :format

    def initialize
      @json = false
      @no_animation = false
      @dry_run = false
      @token = nil
      @podcast_id = nil
      @body = nil
      @file = nil
      @format = nil
      @fields = {}
    end

    def json?
      @json
    end

    def dry_run?
      @dry_run
    end

    def no_animation?
      @no_animation || ENV['BUZZSPROUT_NO_ANIMATION'] == '1'
    end

    def fields
      @fields
    end

    def extract!(args)
      @json = extract_flag!(args, '--json')
      @no_animation = extract_flag!(args, '--no-animation')
      @dry_run = extract_flag!(args, '--dry-run')
      @token = extract_option!(args, '--token')
      @podcast_id = extract_option!(args, '--podcast')
      @file = extract_option!(args, '--file')
      @format = extract_option!(args, '--format')
      raw_body = extract_option!(args, '--body')
      @body = raw_body ? JSON.parse(raw_body) : nil

      extract_kv_fields!(args)
      self
    end

    def self.parse!(args)
      new.tap { |options| options.extract!(args) }
    end

    def merge_body(extra = {})
      data = {}
      data.merge!(@body) if @body.is_a?(Hash)
      data.merge!(@fields)
      extra.each { |key, value| data[key.to_s] = value unless value.nil? }
      data
    end

    def extract_option!(args, flag)
      self.class.extract_option!(args, flag)
    end

    def extract_flag!(args, flag)
      self.class.extract_flag!(args, flag)
    end

    def self.extract_flag!(args, flag)
      !!args.delete(flag)
    end

    def self.extract_option!(args, flag)
      idx = args.index(flag)
      if idx
        args.delete_at(idx)
        return args.delete_at(idx)
      end

      prefix = "#{flag}="
      found = args.find { |arg| arg.start_with?(prefix) }
      return unless found

      args.delete(found)
      found.delete_prefix(prefix)
    end

    private

    FIELD_FLAGS = %w[
      --title --description --author --artist --tags --name --email --role
      --headline --url --guid --feed-url --value --expires-at --position
      --language --timezone --website-address --contact-email --category
      --category2 --category3 --keywords --episode-number --season-number
      --episode-type --published-at --custom-url --start-time --duration
      --aspect-ratio --artwork --timestamp --seconds --eligible --date --page
      --per-page --filename --type --byte-size --transcript-format
      --contributor-id --brand-affiliation-id --text-line-1 --text-line-2
      --background-color --text-color --wave-color
    ].freeze

    BOOLEAN_FLAGS = %w[--private --explicit --multipart --published].freeze

    def extract_kv_fields!(args)
      FIELD_FLAGS.each do |flag|
        value = extract_option!(args, flag)
        next if value.nil?

        key = flag.delete_prefix('--').tr('-', '_')
        @fields[key] = coerce_number(value)
      end

      BOOLEAN_FLAGS.each do |flag|
        key = flag.delete_prefix('--')
        prefix = "#{flag}="
        equals = args.find { |arg| arg.start_with?(prefix) }
        if equals
          args.delete(equals)
          @fields[key] = truthy?(equals.delete_prefix(prefix))
        elsif extract_flag!(args, flag)
          @fields[key] = true
        end
      end
    end

    def truthy?(value)
      %w[1 true yes y on].include?(value.to_s.downcase)
    end

    def coerce_number(value)
      return value.to_i if value =~ /\A-?\d+\z/
      return value.to_f if value =~ /\A-?\d+\.\d+\z/

      value
    end
  end
end

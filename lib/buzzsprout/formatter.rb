# frozen_string_literal: true

require 'json'
require_relative 'podcast_picker'

module Buzzsprout
  class Formatter
    def initialize(io: $stdout)
      @io = io
    end

    def heading(title)
      @io.puts Color.bold(title, io: @io)
      @io.puts '=' * 60
    end

    def kv(label, value)
      return if value.nil? || value == ''

      @io.puts "#{label.ljust(16)} #{value}"
    end

    def list_podcasts(podcasts)
      heading('Podcasts')
      rows = wrap_list(podcasts)
      if rows.empty?
        @io.puts 'No podcasts found.'
        return
      end

      rows.each do |podcast|
        @io.puts PodcastPicker.format_label(podcast, io: @io)
      end
    end

    def show_record(title, record, keys)
      heading(title)
      keys.each { |key| kv(key, record[key]) }
    end

    def list_records(title, records, columns)
      heading(title)
      if records.nil? || records.empty?
        @io.puts 'None found.'
        return
      end

      Array(records).each do |record|
        line = columns.map { |key| record[key] }.compact.join('  ')
        @io.puts line
      end
    end

      def json(data)
      @io.puts JSON.pretty_generate(data.nil? ? { ok: true } : data)
    end

    def wrap_list(data)
      case data
      when Array then data
      when Hash then [data]
      else []
      end
    end
  end
end

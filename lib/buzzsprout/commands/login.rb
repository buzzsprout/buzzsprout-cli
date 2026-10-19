# frozen_string_literal: true

require 'io/console'

module Buzzsprout
  module Commands
    class Login < Base
      USAGE = 'buzzsprout login [--no-animation] [--install-skills|--no-skills]'
      HELP_PAGE = {
        summary: 'Authenticate with a Buzzsprout API token.',
        usage: 'buzzsprout login [--no-animation] [--install-skills|--no-skills]',
        aliases: %w[login auth init],
        flags: [
          ['--token TOKEN', 'Avoid: visible in process list and shell history. Prefer the prompt or BUZZSPROUT_API_TOKEN'],
          ['--no-animation', 'Skip the intro animation'],
          ['--install-skills', 'Install agent skills after login without prompting'],
          ['--no-skills', 'Skip the skills install prompt (--skip-skills)'],
          ['--dir PATH', 'Skills install destination (default ~/.cursor/skills)']
        ],
        examples: [
          'buzzsprout login',
          'buzzsprout login --no-animation',
          'buzzsprout login --install-skills'
        ]
      }.freeze

      def run
        play_intro
        say_hello

        loop do
          token = acquire_token
          if token.to_s.strip.empty?
            @err.puts Color.red('A token is required. Find it in Buzzsprout under Profile → API.', io: @err)
            next if retry?
            return 1
          end

          @io.puts 'Testing connection…'
          @io.puts Color.dim('GET https://www.buzzsprout.com/api/podcasts', io: @io)

          begin
            client = Client.new(token: token.strip, dry_run: @options.dry_run?, io: @err)
            podcasts = client.get('/podcasts') || []
            persist(token.strip, podcasts)
            celebrate(podcasts)
            return 0
          rescue Client::Unauthorized
            @err.puts Color.red('That token was rejected (401).', io: @err)
            @err.puts 'Open Buzzsprout → Profile → API and paste a fresh token.'
          rescue Client::Error => e
            @err.puts Color.red(e.message, io: @err)
          rescue StandardError => e
            @err.puts Color.red("Could not reach Buzzsprout: #{e.message}", io: @err)
          end

          return 1 unless retry?
        end
      end

      private

      def play_intro
        return if @options.no_animation?

        Animation.new(io: @io).play
      end

      def say_hello
        @io.puts Color.bold('Welcome to the Buzzsprout CLI', io: @io)
        @io.puts '=' * 40
        @io.puts 'Authenticate with the token from Profile → API.'
        @io.puts Color.dim('Tip: set BUZZSPROUT_API_TOKEN in the environment instead of pasting on argv.', io: @io)
        @io.puts ''
      end

      def acquire_token
        return @options.token unless @options.token.to_s.empty?
        return ENV['BUZZSPROUT_API_TOKEN'] unless ENV['BUZZSPROUT_API_TOKEN'].to_s.empty?

        prompt_token
      end

      def prompt_token
        @io.print 'API token: '
        @io.flush if @io.respond_to?(:flush)
        token = if @stdin.respond_to?(:noecho) && @stdin.respond_to?(:tty?) && @stdin.tty?
                  @stdin.noecho(&:gets).to_s
                else
                  @stdin.gets.to_s
                end
        @io.puts ''
        token.strip
      rescue StandardError
        @stdin.gets.to_s.strip
      end

      def persist(token, podcasts)
        config = { api_token: token }
        list = PodcastPicker.wrap_list(podcasts)
        if (explicit = @options.podcast_id || ENV['BUZZSPROUT_PODCAST_ID'])
          config[:default_podcast_id] = explicit
        elsif list.size == 1
          config[:default_podcast_id] = list.first['id']
        end
        Config.save(config)
      end

      def celebrate(podcasts)
        @io.puts ''
        @io.puts Color.rgb('Authentication Successful', Animation::BOLT_COLOR, io: @io)
        list = PodcastPicker.wrap_list(podcasts)
        @io.puts ''
        @io.puts Color.dim("Token saved to #{Config.config_file} (mode 0600).", io: @io)
        @io.puts ''
        if list.empty?
          @io.puts 'No podcasts on this account yet — create one in Buzzsprout, then run:'
          @io.puts '  buzzsprout podcasts'
        elsif list.size == 1
          podcast = list.first
          @io.puts "Default podcast: #{podcast['id']}  #{podcast['title']}"
          @io.puts ''
          print_next_steps
        else
          pick_default_after_login(list)
        end
        offer_skills_install
      end

      def pick_default_after_login(list)
        if !@options.podcast_id.to_s.empty? || !ENV['BUZZSPROUT_PODCAST_ID'].to_s.empty?
          print_podcast_list(list)
          print_next_steps
          return
        end

        unless interactive_podcast_picker?
          print_podcast_list(list)
          @io.puts 'Set a default with:  buzzsprout podcast use'
          print_next_steps
          return
        end

        begin
          chosen = PodcastPicker.choose!(
            list,
            io: @io,
            stdin: @stdin,
            default_id: Config.default_podcast_id,
            auto_single: false
          )
          Config.save(default_podcast_id: chosen['id'])
          @io.puts "Default podcast set to #{chosen['id']}  #{chosen['title']}."
        rescue PodcastPicker::Cancelled
          @io.puts 'No default podcast set. Run `buzzsprout podcast use` when you are ready.'
        end
        print_next_steps
      end

      def print_next_steps
        @io.puts 'Try:  buzzsprout podcasts'
        @io.puts '      buzzsprout episodes list'
      end

      def offer_skills_install
        return if @options.dry_run?

        dest = Skills.destination_dir(@options.dir)
        if @options.install_skills?
          @io.puts ''
          Skills.install_into!(dest, io: @io)
          return
        end
        return if @options.skip_skills?
        return if Skills.installed?(dest)
        return unless interactive_skills_prompt?

        @io.puts ''
        @io.print 'Install agent skills now? [Y/n] '
        @io.flush if @io.respond_to?(:flush)
        answer = @stdin.gets.to_s.strip
        if %w[n no].include?(answer.downcase)
          @io.puts 'Skipped. Install later with:  buzzsprout skills install'
          return
        end

        Skills.install_into!(dest, io: @io)
      end

      def interactive_skills_prompt?
        return false if @options.json?
        return false if ENV['BUZZSPROUT_NONINTERACTIVE'] == '1'
        return false unless @stdin.respond_to?(:tty?) && @stdin.tty?

        true
      end

      def print_podcast_list(list)
        @io.puts Color.bold("#{list.size} podcast#{list.size == 1 ? '' : 's'} ready:", io: @io)
        list.each do |podcast|
          @io.puts "  *  #{podcast['id']}  #{podcast['title']}"
        end
        @io.puts ''
      end

      def retry?
        unless @stdin.respond_to?(:tty?) && @stdin.tty?
          return false
        end

        @io.print 'Retry / re-enter token? [Y/n] '
        answer = @stdin.gets.to_s.strip
        answer.empty? || %w[y yes].include?(answer.downcase)
      end

    end
  end
end

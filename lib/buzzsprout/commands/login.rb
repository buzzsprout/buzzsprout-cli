# frozen_string_literal: true

require 'io/console'

module Buzzsprout
  module Commands
    class Login < Base
      USAGE = 'buzzsprout login [--no-animation] [--install-skills|--no-skills]'
      HELP_PAGE = {
        summary: 'Connect your Buzzsprout account in your browser.',
        usage: 'buzzsprout login [--no-animation] [--install-skills|--no-skills]',
        aliases: %w[login auth init],
        flags: [
          ['--api-token', 'Use the API token prompt instead of browser login'],
          ['--no-browser', 'Print the authorization link without opening a browser'],
          ['--token TOKEN', 'Avoid: visible in process list and shell history. Prefer the prompt or BUZZSPROUT_API_TOKEN'],
          ['--no-animation', 'Skip the intro animation'],
          ['--install-skills', 'Install agent skills after login without prompting'],
          ['--no-skills', 'Skip the skills install prompt (--skip-skills)'],
          ['--dir PATH', 'Override detected agent skills directories']
        ],
        examples: [
          'buzzsprout login',
          'buzzsprout login --no-animation',
          'buzzsprout login --install-skills'
        ]
      }.freeze

      def run
        token_login = @args.delete('--api-token') || @options.token || !ENV['BUZZSPROUT_API_TOKEN'].to_s.empty?
        return oauth_login unless token_login

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

      def oauth_login
        raise 'Login cannot run with --dry-run.' if @options.dry_run?
        play_intro
        say_hello(oauth: true)
        open_browser = !@args.delete('--no-browser')
        credentials = podcasts = nil
        loop do
          begin
            credentials = OAuth.authorize(io: @io, open_browser: open_browser)
            @io.puts 'Testing connection…'
            @io.puts Color.dim("GET #{Config.api_base_url}/podcasts", io: @io)
            podcasts = Client.new(token: credentials[:access_token], auth_scheme: 'Bearer').get('/podcasts') || []
            break
          rescue StandardError => e
            @err.puts Color.red("Could not connect: #{e.message}", io: @err)
            return 1 unless retry?(prompt: 'Retry browser login? [Y/n] ')
          end
        end
        Config.with_lock do
          Config.clear_cache
          list = PodcastPicker.wrap_list(podcasts)
          saved_id = Config.saved_podcast_id
          saved_id = nil unless list.any? { |podcast| podcast['id'].to_s == saved_id.to_s }
          default_id = @options.podcast_id || ENV['BUZZSPROUT_PODCAST_ID'] || saved_id || (list.first['id'] if list.size == 1)
          Config.save(auth_method: 'oauth', oauth: credentials, api_token: nil, token: nil, default_podcast_id: default_id, podcast_id: nil)
        end
        celebrate(podcasts)
        0
      end

      def play_intro
        return if @options.no_animation?

        Animation.new(io: @io).play
      end

      def say_hello(oauth: false)
        @io.puts Color.bold('Welcome to the Buzzsprout CLI', io: @io)
        @io.puts '=' * 40
        if oauth
          @io.puts 'Sign in to Buzzsprout in your browser to connect your account.'
        else
          @io.puts 'Authenticate with the token from Profile → API.'
          @io.puts Color.dim('Tip: set BUZZSPROUT_API_TOKEN in the environment instead of pasting on argv.', io: @io)
        end
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
        config = { api_token: token, auth_method: 'api_token', oauth: nil }
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

        destinations = Skills.destination_dirs(@options.dir)
        if destinations.empty?
          @io.puts 'To install agent skills, run: buzzsprout skills install --dir PATH' unless @options.skip_skills?
          return
        end
        if @options.install_skills?
          @io.puts ''
          destinations.each { |dest| Skills.install_into!(dest, io: @io) }
          return
        end
        return if @options.skip_skills?
        return if destinations.all? { |dest| Skills.installed?(dest) }
        return unless interactive_skills_prompt?

        @io.puts ''
        @io.puts 'Install or refresh skills in:'
        destinations.each { |dest| @io.puts "  #{dest}" }
        @io.print 'Install agent skills now? [Y/n] '
        @io.flush if @io.respond_to?(:flush)
        answer = @stdin.gets.to_s.strip
        if %w[n no].include?(answer.downcase)
          @io.puts 'Skipped. Install later with:  buzzsprout skills install'
          return
        end

        destinations.each { |dest| Skills.install_into!(dest, io: @io) }
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

      def retry?(prompt: 'Retry / re-enter token? [Y/n] ')
        return false if ENV['BUZZSPROUT_NONINTERACTIVE'] == '1' || @options.json?
        unless @stdin.respond_to?(:tty?) && @stdin.tty?
          return false
        end

        @io.print prompt
        answer = @stdin.gets.to_s.strip
        answer.empty? || %w[y yes].include?(answer.downcase)
      end

    end
  end
end

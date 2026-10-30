# frozen_string_literal: true

require 'json'
require_relative 'version'
require_relative 'config'
require_relative 'redact'
require_relative 'color'
require_relative 'options'
require_relative 'client'
require_relative 'oauth'
require_relative 'formatter'
require_relative 'animation'
require_relative 'podcast_picker'
require_relative 'commands/base'
require_relative 'commands/login'
require_relative 'commands/status'
require_relative 'commands/podcasts'
require_relative 'commands/episodes'
require_relative 'commands/uploads'
require_relative 'commands/downloads'
require_relative 'commands/team'
require_relative 'commands/contributors'
require_relative 'commands/brand_affiliations'
require_relative 'commands/chapters'
require_relative 'commands/transcripts'
require_relative 'commands/listings'
require_relative 'commands/podrolls'
require_relative 'commands/feed_verifications'
require_relative 'commands/fan_mail'
require_relative 'commands/skills'

module Buzzsprout
  class CLI
    HELP = <<~HELP
      Buzzsprout CLI #{VERSION} — agent-friendly API client

      Usage: buzzsprout [command] [args] [options]

      First run / auth
        login, auth, init     Connect in your browser; --api-token for token login
                              After success, may offer to install agent skills
        logout                Remove ~/.buzzsprout.json
        status, whoami        Show whether a token is saved

      Podcasts & episodes
        podcasts [list]
        podcast use [id]      Set the saved podcast (picker if omitted)
        podcasts show <id>
        podcasts update <id> --title "…"
        episodes list [podcast_id]
        episodes show <podcast_id> <episode_id>
        episodes create <podcast_id> --title "…" [--private]
        episodes update|publish|unpublish <podcast_id> <episode_id>
        episode <id> downloads today|yesterday|YYYY-MM-DD
        downloads today|yesterday|YYYY-MM-DD
        uploads start <podcast_id> <episode_id> --file PATH
        uploads complete|abort <podcast_id> <episode_id> <upload_id>

      More resources
        team list|invite|update|delete <podcast_id> [id]
        contributors list|show|create|update|delete|assign|unassign …
        brand-affiliations list|show|create|update|delete|assign|unassign …
        chapters list|replace <podcast_id> <episode_id>
        transcripts show|upload|delete|high-fidelity|replace-high-fidelity …
        listings [directory] [url|status]
        listings submit-all
        podrolls list|create|update|delete <podcast_id> [id]
        feed-verifications list|create|update|delete <podcast_id> [id]
        fan-mail list|show|publish|unpublish|read|block <podcast_id> [id]
        insertion-points list|create|update|delete <podcast_id> <episode_id> [id]
        soundbites show|create|delete <podcast_id> <episode_id>
        skills [list|path|install --dir DIR]

      Global options
        --json                Print raw JSON
        --body '{…}'          JSON request body
        --file PATH           Upload a local file
        --token TOKEN         Login only; leaks via process list/history — prefer prompt or env
        --podcast ID, --in ID Podcast id for this invocation (skips the picker)
        --dry-run             Print the request without sending it
        --no-animation        Skip the first-run ASCII animation
        --install-skills      After login, install agent skills without prompting
        --no-skills           Skip the post-login skills prompt
        --help, -h            Show this help
        --version, -v         Show version

      Environment
        BUZZSPROUT_API_TOKEN  Token override (never print or commit this)
        BUZZSPROUT_PODCAST_ID Explicit podcast id (skips the picker)
        BUZZSPROUT_NONINTERACTIVE=1  Never open the podcast picker or skills prompt
        BUZZSPROUT_CONFIG     Config path (default ~/.buzzsprout.json)
        BUZZSPROUT_SKILLS_DIR Skills install destination (default ~/.cursor/skills)
        BUZZSPROUT_API_BASE   API base (default https://www.buzzsprout.com/api)
        BUZZSPROUT_NO_ANIMATION=1
        BUZZSPROUT_THEME      dark|light (intro contrast; auto-detects otherwise)
        NO_COLOR              Disable ANSI color
    HELP

    DOWNLOAD_VERBS = %w[downloads stats].freeze

    ROUTES = {
      'login' => Commands::Login,
      'auth' => Commands::Login,
      'init' => Commands::Login,
      'logout' => Commands::Logout,
      'status' => Commands::Status,
      'whoami' => Commands::Status,
      'podcasts' => Commands::Podcasts,
      'podcast' => Commands::Podcasts,
      'episodes' => Commands::Episodes,
      'episode' => Commands::Episodes,
      'uploads' => Commands::Uploads,
      'upload' => Commands::Uploads,
      'downloads' => Commands::Downloads,
      'stats' => Commands::Downloads,
      'team' => Commands::Team,
      'contributors' => Commands::Contributors,
      'brand-affiliations' => Commands::BrandAffiliations,
      'brand_affiliations' => Commands::BrandAffiliations,
      'brands' => Commands::BrandAffiliations,
      'chapters' => Commands::Chapters,
      'transcripts' => Commands::Transcripts,
      'listings' => Commands::Listings,
      'podrolls' => Commands::Podrolls,
      'feed-verifications' => Commands::FeedVerifications,
      'feed_verifications' => Commands::FeedVerifications,
      'fan-mail' => Commands::FanMail,
      'fan_mail' => Commands::FanMail,
      'insertion-points' => Commands::InsertionPoints,
      'insertion_points' => Commands::InsertionPoints,
      'soundbites' => Commands::Soundbites,
      'soundbite' => Commands::Soundbites,
      'skills' => Commands::Skills
    }.freeze

    def initialize(io: $stdout, err: $stderr, stdin: $stdin)
      @io = io
      @err = err
      @stdin = stdin
    end

    def run(argv)
      args = argv.dup
      if args.empty?
        return first_run_or_help
      end

      if %w[help --help -h].include?(args.first)
        @io.puts HELP
        return 0
      end

      if %w[version --version -v].include?(args.first)
        @io.puts "buzzsprout-cli #{VERSION}"
        return 0
      end

      options = Options.parse!(args)
      command = args.shift
      if %w[episode episodes].include?(command) && args.any? { |arg| DOWNLOAD_VERBS.include?(arg) }
        return run_episode_downloads(args, options)
      end

      klass = ROUTES[command]
      unless klass
        @err.puts "Unknown command: #{command}"
        @io.puts HELP
        return 1
      end

      status = klass.new(args, options, io: @io, err: @err, stdin: @stdin).run
      status.nil? ? 0 : status
    rescue PodcastPicker::Cancelled => e
      @err.puts Redact.string(e.message)
      1
    rescue Client::Unauthorized => e
      @err.puts "Error: #{Redact.string(e.message)}"
      @err.puts "Run 'buzzsprout login' to save a new token."
      1
    rescue StandardError => e
      @err.puts "Error: #{Redact.string(e.message)}"
      1
    end

    private

    def run_episode_downloads(args, options)
      unless args[0].to_s.match?(/\A\d+\z/) && DOWNLOAD_VERBS.include?(args[1].to_s)
        return Commands::Downloads.new([], options, io: @io, err: @err, stdin: @stdin).run
      end

      episode_id = args.shift
      args.shift
      command = Commands::Downloads.new(args, options, io: @io, err: @err, stdin: @stdin)
      command.episode_id = episode_id
      command.run
    end

    def first_run_or_help
      unless Config.configured?
        return Commands::Login.new([], Options.new, io: @io, err: @err, stdin: @stdin).run
      end

      @io.puts HELP
      0
    end
  end
end

# frozen_string_literal: true

require 'json'
require_relative 'version'
require_relative 'config'
require_relative 'color'
require_relative 'options'
require_relative 'client'
require_relative 'formatter'
require_relative 'animation'
require_relative 'podcast_picker'
require_relative 'commands/base'
require_relative 'commands/login'
require_relative 'commands/status'
require_relative 'commands/podcasts'
require_relative 'commands/episodes'
require_relative 'commands/uploads'
require_relative 'commands/stats'
require_relative 'commands/team'
require_relative 'commands/contributors'
require_relative 'commands/brand_affiliations'
require_relative 'commands/chapters'
require_relative 'commands/transcripts'
require_relative 'commands/listings'
require_relative 'commands/fan_mail'
require_relative 'commands/skills'

module Buzzsprout
  class CLI
    HELP = <<~HELP
      Buzzsprout CLI #{VERSION} — agent-friendly API client

      Usage: buzzsprout [command] [args] [options]

      First run / auth
        login, auth, init     Logo animation, prompt for API token, test GET /podcasts
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
        uploads start <podcast_id> <episode_id> --file PATH
        uploads complete|abort <podcast_id> <episode_id> <upload_id>

      More resources
        stats --date YYYY-MM-DD
        stats episode <episode_id> --date YYYY-MM-DD
        team list|invite|update|delete <podcast_id> [id]
        contributors list|show|create|update|delete|assign|unassign …
        brand-affiliations list|show|create|update|delete|assign|unassign …
        chapters list|replace <podcast_id> <episode_id>
        transcripts show|upload|delete|high-fidelity|replace-high-fidelity …
        listings list|submit-all <podcast_id>
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
        --token TOKEN         Override the saved / env token for login
        --podcast ID, --in ID Podcast id for this invocation (skips the picker)
        --dry-run             Print the request without sending it
        --no-animation        Skip the first-run ASCII animation
        --help, -h            Show this help
        --version, -v         Show version

      Environment
        BUZZSPROUT_API_TOKEN  Token override (never commit this)
        BUZZSPROUT_PODCAST_ID Explicit podcast id (skips the picker)
        BUZZSPROUT_NONINTERACTIVE=1  Never open the podcast picker
        BUZZSPROUT_CONFIG     Config path (default ~/.buzzsprout.json)
        BUZZSPROUT_API_BASE   API base (default https://www.buzzsprout.com/api)
        BUZZSPROUT_NO_ANIMATION=1
        BUZZSPROUT_THEME      dark|light (intro contrast; auto-detects otherwise)
        NO_COLOR              Disable ANSI color
    HELP

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
      'stats' => Commands::Stats,
      'downloads' => Commands::Stats,
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
      klass = ROUTES[command]
      unless klass
        @err.puts "Unknown command: #{command}"
        @io.puts HELP
        return 1
      end

      status = klass.new(args, options, io: @io, err: @err, stdin: @stdin).run
      status.nil? ? 0 : status
    rescue PodcastPicker::Cancelled => e
      @err.puts e.message
      1
    rescue Client::Unauthorized => e
      @err.puts "Error: #{e.message}"
      @err.puts "Run 'buzzsprout login' to save a new token."
      1
    rescue StandardError => e
      @err.puts "Error: #{e.message}"
      1
    end

    private

    def first_run_or_help
      unless Config.configured?
        return Commands::Login.new([], Options.new, io: @io, err: @err, stdin: @stdin).run
      end

      @io.puts HELP
      0
    end
  end
end

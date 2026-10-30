# frozen_string_literal: true

module Buzzsprout
  module Commands
    class Logout < Base
      USAGE = 'buzzsprout logout'
      HELP_PAGE = {
        summary: 'Disconnect and remove saved credentials and the default podcast.',
        usage: 'buzzsprout logout [--local-only]',
        flags: [['--local-only', 'Forget saved credentials without revoking the OAuth connection']],
        aliases: %w[logout],
        examples: ['buzzsprout logout']
      }.freeze

      def run
        Config.with_lock do
          Config.clear_cache
          credentials = Config.loaded[:oauth]
          OAuth.revoke(credentials) if credentials && !@args.delete('--local-only')
          Config.delete!
        end
        @io.puts "Logged out. Removed #{Config.config_file}."
        0
      end
    end

    class Status < Base
      USAGE = 'buzzsprout status'
      HELP_PAGE = {
        summary: 'Show whether a token and default podcast are saved.',
        usage: 'buzzsprout status',
        aliases: %w[status whoami],
        examples: ['buzzsprout status']
      }.freeze

      def run
        if Config.configured?
          payload = {
            authenticated: true,
            auth_method: Config.oauth? ? 'oauth' : 'api_token',
            token_set: true,
            config_file: Config.config_file,
            default_podcast_id: Config.default_podcast_id,
            api_base: Config.api_base_url,
            user_agent: Client::USER_AGENT
          }
          output(payload) do
            @io.puts Color.green('Authenticated', io: @io)
            @formatter.kv('Config', Config.config_file)
            @formatter.kv('Method', Config.oauth? ? 'OAuth' : 'API token')
            @formatter.kv('Podcast', Config.default_podcast_id)
            @formatter.kv('API', Config.api_base_url)
          end
        else
          payload = { authenticated: false, token_set: false, config_file: Config.config_file }
          output(payload) do
            @io.puts 'Not authenticated. Run `buzzsprout login`.'
          end
        end
        0
      end
    end
  end
end

# frozen_string_literal: true

module Buzzsprout
  module Commands
    class Logout < Base
      USAGE = 'buzzsprout logout'
      HELP_PAGE = {
        summary: 'Remove the saved token and default podcast.',
        usage: 'buzzsprout logout',
        aliases: %w[logout],
        examples: ['buzzsprout logout']
      }.freeze

      def run
        Config.delete!
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
          token = Config.token.to_s
          masked = if token.length > 8
                     "#{token[0, 4]}…#{token[-4, 4]}"
                   else
                     '[set]'
                   end
          payload = {
            authenticated: true,
            config_file: Config.config_file,
            token: masked,
            default_podcast_id: Config.default_podcast_id,
            api_base: Config.api_base_url,
            user_agent: Client::USER_AGENT
          }
          output(payload) do
            @io.puts Color.green('Authenticated', io: @io)
            @formatter.kv('Config', Config.config_file)
            @formatter.kv('Token', masked)
            @formatter.kv('Podcast', Config.default_podcast_id)
            @formatter.kv('API', Config.api_base_url)
          end
        else
          payload = { authenticated: false, config_file: Config.config_file }
          output(payload) do
            @io.puts 'Not authenticated. Run `buzzsprout login`.'
          end
        end
        0
      end
    end
  end
end

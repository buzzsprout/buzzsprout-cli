# frozen_string_literal: true

module Buzzsprout
  module Commands
    class Logout < Base
      USAGE = 'buzzsprout logout'

      def run
        Config.delete!
        @io.puts "Logged out. Removed #{Config.config_file}."
        0
      end
    end

    class Status < Base
      USAGE = 'buzzsprout status'

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

    class Use < Base
      USAGE = 'buzzsprout use <podcast_id>'

      def run
        id = shift_id!('podcast_id')
        Config.save(default_podcast_id: id)
        @io.puts "Default podcast set to #{id}."
        0
      end
    end
  end
end

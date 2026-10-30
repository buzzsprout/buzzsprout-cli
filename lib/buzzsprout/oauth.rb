# frozen_string_literal: true

require 'net/http'
require 'socket'
require 'securerandom'
require 'digest'
require 'timeout'

module Buzzsprout
  module OAuth
    CLIENT_ID = ''.freeze # Set to the registered public CLI application ID before release.
    CALLBACK_PATH = '/oauth/callback'
    module_function

    def issuer
      uri = URI(Config.api_base_url)
      raise 'Invalid API URL' unless %w[https http].include?(uri.scheme) && uri.host && !uri.userinfo
      "#{uri.scheme}://#{uri.host}#{uri.port == uri.default_port ? '' : ":#{uri.port}"}"
    end

    def client_id
      ENV['BUZZSPROUT_OAUTH_CLIENT_ID'].to_s.empty? ? CLIENT_ID : ENV['BUZZSPROUT_OAUTH_CLIENT_ID']
    end

    def token_request(parameters, server: issuer)
      uri = URI("#{server}/oauth/token")
      request = Net::HTTP::Post.new(uri)
      request['User-Agent'] = Client::USER_AGENT
      request['Accept'] = 'application/json'
      request.set_form_data(parameters)
      response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == 'https', open_timeout: 15, read_timeout: 30) { |http| http.request(request) }
      raise "OAuth authorization failed. Run 'buzzsprout login' to reconnect." unless response.is_a?(Net::HTTPSuccess)
      data = JSON.parse(response.body)
      unless data.is_a?(Hash) && data['access_token'].is_a?(String) && !data['access_token'].empty? && data['refresh_token'].is_a?(String) && !data['refresh_token'].empty? && data['token_type'].to_s.downcase == 'bearer' && data['expires_in'].to_i.positive?
        raise 'Invalid OAuth token response. Run buzzsprout login again.'
      end
      { access_token: data['access_token'], refresh_token: data['refresh_token'], expires_at: Time.now.to_i + data['expires_in'].to_i }
    rescue JSON::ParserError
      raise 'Invalid OAuth token response. Run buzzsprout login again.'
    end

    def authorize(io:, open_browser: true, timeout: 300)
      id = client_id
      raise 'OAuth client registration is not configured. Set BUZZSPROUT_OAUTH_CLIENT_ID for local testing.' if id.empty?
      server = TCPServer.new('127.0.0.1', 0)
      redirect = "http://127.0.0.1:#{server.addr[1]}#{CALLBACK_PATH}"
      state = SecureRandom.hex(32)
      verifier = SecureRandom.urlsafe_base64(48)
      challenge = [Digest::SHA256.digest(verifier)].pack('m0').tr('+/', '-_').delete('=')
      origin = issuer
      url = "#{origin}/oauth/authorize?#{URI.encode_www_form(response_type: 'code', client_id: id, redirect_uri: redirect, state: state, code_challenge: challenge, code_challenge_method: 'S256')}"
      io.puts "Open this link to connect your Buzzsprout account:\n\n#{url}\n\nWaiting for authorization…"
      io.flush if io.respond_to?(:flush)
      launch_browser(url) if open_browser
      code = wait_for_callback(server, state: state, issuer: origin, timeout: timeout)
      token_request({ grant_type: 'authorization_code', client_id: id, code: code, redirect_uri: redirect, code_verifier: verifier }, server: origin).merge(client_id: id, issuer: origin, api_base: Config.api_base_url)
    rescue Interrupt
      raise 'Authorization cancelled. Run buzzsprout login to try again.'
    ensure
      server&.close
    end

    def wait_for_callback(server, state:, issuer:, timeout:)
      deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + timeout
      loop do
        remaining = deadline - Process.clock_gettime(Process::CLOCK_MONOTONIC)
        raise 'Authorization timed out. Run buzzsprout login again.' unless remaining.positive? && IO.select([server], nil, nil, remaining)
        socket = server.accept
        begin
          line = Timeout.timeout([remaining, 5].min) { socket.gets(8192) }
          method, target, = line.to_s.split(' ')
          uri = URI(target.to_s)
          params = URI.decode_www_form(uri.query.to_s).to_h
          valid = method == 'GET' && uri.path == CALLBACK_PATH && params['state'] == state && params['iss'] == issuer
          code = params['code'] if valid
          denied = valid && params['error']
          message = callback_page(success: code && !code.empty?, client: :cli)
          socket.write "HTTP/1.1 #{valid ? '200 OK' : '400 Bad Request'}\r\nContent-Type: text/html; charset=utf-8\r\nCache-Control: no-store\r\nReferrer-Policy: no-referrer\r\nContent-Security-Policy: default-src 'none'; style-src 'unsafe-inline'; base-uri 'none'\r\nConnection: close\r\nContent-Length: #{message.bytesize}\r\n\r\n#{message}"
          raise 'Authorization was declined. Run buzzsprout login to try again.' if denied
          return code if code && !code.empty?
        rescue Timeout::Error, URI::InvalidURIError, ArgumentError, IOError, SystemCallError
          # Ignore unrelated or incomplete local requests while awaiting the callback.
        ensure
          socket.close
        end
      end
    end

    def callback_page(success:, client: nil)
      cli = client == :cli
      title = success ? (cli ? "All systems go." : "You’re all set.") : "That connection didn’t make it through."
      detail = if success
                 cli ? 'Connection approved.<br>Return to your terminal to finish connecting.' : 'Connection approved.<br>Return to your app to finish connecting.'
               else
                 cli ? 'Head back to your terminal for details and try again.' : 'Return to your app for details and try again.'
               end
      <<~HTML
        <!doctype html>
        <html lang="en">
        <head>
          <meta charset="utf-8">
          <meta name="viewport" content="width=device-width, initial-scale=1">
          <title>Buzzsprout · Connect #{cli ? "to the CLI" : "your app"}</title>
          <style>
            * { box-sizing: border-box; }
            body { margin: 0; min-height: 100vh; background: #fff; color: #151E1B; font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif; }
            header { height: 64px; background: #F4F4F4; display: flex; justify-content: center; }
            .logo { display: grid; place-items: center; width: 88px; height: 88px; margin-top: 32px; border-radius: 50%; background: white; }
            .logo svg { width: 50px; height: 53px; }
            main { width: min(calc(100% - 32px), 720px); margin: 105px auto 60px; text-align: center; padding: 32px 20px 48px; }
            .art { margin: 36px auto; display: flex; justify-content: center; align-items: center; gap: 13px; }
            .mic, .terminal { display: grid; place-items: center; width: 72px; height: 72px; border-radius: 22px; background: #E5EDE9; color: #396252; }
            .terminal { background: #214538; color: #B8F2B4; font: bold 23px monospace; }
            .wave { position: relative; width: 90px; height: 3px; border-radius: 4px; background: #CCDBD3; }
            .wave::after { content: ''; position: absolute; left: 0; top: 50%; width: 12px; height: 12px; border-radius: 50%; background: #40d134; transform: translateY(-50%); box-shadow: 0 0 0 6px #E5FFE3; }
            .failure .wave::after { animation: attempt .65s ease-in-out .3s both, vanish .01s linear .95s forwards; }
            .failure .wave::before { content: '×'; position: absolute; left: 50%; top: 50%; z-index: 1; width: 27px; height: 27px; display: grid; place-items: center; border-radius: 50%; transform: translate(-50%, -50%); background: #FDF3D4; color: #7F4B14; box-shadow: 0 0 0 5px white; font: 700 20px/1 sans-serif; opacity: 0; animation: fail-shake .65s ease-in-out .95s forwards; }
            @keyframes attempt { from { left: 0; } to { left: calc(50% - 6px); } }
            @keyframes fail-shake { 0% { opacity: 0; transform: translate(-50%, -50%) scale(.5); } 15% { opacity: 1; transform: translate(-50%, -50%) scale(1); } 35%, 65% { opacity: 1; transform: translate(calc(-50% - 5px), -50%); } 50%, 80% { opacity: 1; transform: translate(calc(-50% + 5px), -50%); } 100% { opacity: 1; transform: translate(-50%, -50%); } }
            .success .wave::after { animation: travel 1.2s ease-in-out .3s both, return-to-middle .35s ease-in 1.5s forwards, vanish .01s linear 1.85s forwards; }
            .success .wave::before { content: '✓'; position: absolute; left: 50%; top: 50%; z-index: 1; width: 27px; height: 27px; display: grid; place-items: center; transform: translate(-50%, -50%) scale(.5); border-radius: 50%; background: #DBF9D9; color: #195017; box-shadow: 0 0 0 5px white; font: 800 16px/1 sans-serif; opacity: 0; animation: check-bounce .7s cubic-bezier(.2, .8, .3, 1) 1.85s forwards; }
            .success .terminal { animation: pop .6s cubic-bezier(.2, 1.6, .4, 1) 1.4s both; }
            @keyframes travel { from { left: 0; } to { left: calc(100% - 12px); } }
            @keyframes return-to-middle { from { left: calc(100% - 12px); } to { left: calc(50% - 6px); } }
            @keyframes pop { 0% { transform: scale(1); } 45% { transform: scale(1.18) rotate(-5deg); box-shadow: 0 0 0 12px #E5FFE3; } 100% { transform: scale(1); box-shadow: 0 0 0 0 transparent; } }
            @keyframes vanish { to { opacity: 0; } }
            @keyframes check-bounce { 0% { opacity: 0; transform: translate(-50%, -50%) scale(.45); } 25% { opacity: 1; transform: translate(-50%, -65%) scale(1.3); box-shadow: 0 0 0 12px rgba(64, 209, 52, .18); } 50% { opacity: 1; transform: translate(-50%, -45%) scale(.9); } 75% { opacity: 1; transform: translate(-50%, -55%) scale(1.08); } 100% { opacity: 1; transform: translate(-50%, -50%) scale(1); box-shadow: 0 0 0 5px white; } }
            @media (prefers-reduced-motion: reduce) { *, *::before, *::after { animation: none !important; } .success .wave::after, .failure .wave::after { opacity: 0; } .success .wave::before, .failure .wave::before { opacity: 1; transform: translate(-50%, -50%); } }
            h1 { margin: 18px 0 12px; font-size: clamp(28px, 6vw, 36px); letter-spacing: -.04em; }
            p { margin: 0 auto; max-width: 620px; line-height: 1.6; color: #396252; }
            .close { margin-top: 24px; font-size: 14px; color: #747576; }
          </style>
        </head>
        <body>
          <header><div class="logo" role="img" aria-label="Buzzsprout"><svg width="50" height="53" viewBox="0 0 50 53" fill="none" xmlns="http://www.w3.org/2000/svg">
<path d="M24.9923 15.0135L25.0209 0.928619H24.6767L10.2906 27.8003H25.0066L24.9994 41.7991H25.3078L39.7225 15.0135H24.9923Z" fill="#40D134"/>
<path d="M17.2762 35.5168C12.7653 31.006 6.76274 28.5174 0.380091 28.5103H0L0.0143434 28.8832C0.286861 35.1439 2.87578 41.0317 7.31494 45.4709C11.7541 49.9101 17.6419 52.499 23.9027 52.7715L24.2756 52.7858V52.4058C24.2756 46.0231 21.7799 40.0277 17.269 35.5097L17.2762 35.5168Z" fill="#214538"/>
<path d="M49.6271 28.5031C43.2445 28.5031 37.2491 30.9988 32.7311 35.5097C28.2202 40.0205 25.7317 46.0231 25.7245 52.4057V52.7858L26.0974 52.7715C32.3581 52.499 38.2459 49.9101 42.6851 45.4709C47.1243 41.0317 49.7132 35.1439 49.9857 28.8832L50.0001 28.5103H49.62L49.6271 28.5031Z" fill="#214538"/>
</svg></div></header>
          <main class="#{success ? 'success' : 'failure'}">
            <div class="art" aria-hidden="true">
              <div class="mic"><svg width="34" height="34" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round"><rect x="9" y="2" width="6" height="12" rx="3"/><path d="M5 11a7 7 0 0 0 14 0M12 18v4m-4 0h8"/></svg></div>
              <div class="wave"></div>
              <div class="terminal">#{cli ? "&gt;_" : '<svg width="38" height="38" viewBox="0 0 38 38" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="4" y="6" width="30" height="26" rx="5"/><path d="M4 13h30M10 9.5h.01M14 9.5h.01M21 16l1.5 3.5L26 21l-3.5 1.5L21 26l-1.5-3.5L16 21l3.5-1.5L21 16Z"/></svg>'}</div>
            </div>
            <h1>#{title}</h1>
            <p>#{detail}</p>
            <p class="close">You can close this tab.</p>
          </main>
        </body>
        </html>
      HTML
    end

    def launch_browser(url)
      command = if RUBY_PLATFORM.include?('darwin')
                  ['open', url]
                elsif RUBY_PLATFORM.match?(/mswin|mingw/)
                  ['rundll32', 'url.dll,FileProtocolHandler', url]
                else
                  ['xdg-open', url]
                end
      pid = Process.spawn(*command, out: File::NULL, err: File::NULL)
      Process.detach(pid)
    rescue SystemCallError
      nil # The printed link remains available.
    end

    def revoke(data)
      uri = URI("#{data.fetch(:issuer)}/oauth/revoke")
      request = Net::HTTP::Post.new(uri)
      request['User-Agent'] = Client::USER_AGENT
      request.set_form_data(client_id: data.fetch(:client_id), token: data.fetch(:refresh_token), token_type_hint: 'refresh_token')
      response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == 'https', open_timeout: 15, read_timeout: 30) { |http| http.request(request) }
      raise 'Could not disconnect. Retry logout, or use --local-only to forget this connection on this computer.' unless response.is_a?(Net::HTTPSuccess)
    end

    def access_token
      Config.with_lock do
        Config.clear_cache
        data = Config.loaded[:oauth]
        raise 'Run buzzsprout login to connect to this server.' unless data && data[:api_base] == Config.api_base_url && data[:issuer] == issuer
        if data[:expires_at].to_i <= Time.now.to_i + 60
          updated = token_request({ grant_type: 'refresh_token', client_id: data[:client_id], refresh_token: data[:refresh_token] }, server: data[:issuer])
          data = data.merge(updated)
          Config.save(oauth: data)
        end
        data[:access_token]
      end
    end
  end
end

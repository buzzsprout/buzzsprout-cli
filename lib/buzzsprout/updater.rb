# frozen_string_literal: true

require 'net/http'
require 'open3'
require 'rbconfig'
require 'timeout'

module Buzzsprout
  class Updater
    REPOSITORY = 'https://github.com/buzzsprout/buzzsprout-cli.git'
    LEGACY_REPOSITORY = 'https://github.com/higher-pixels/buzzsprout-cli.git'
    ENDPOINT = 'https://api.github.com/repos/buzzsprout/buzzsprout-cli/commits/main'
    INTERVAL = 86_400

    def initialize(root: File.expand_path('../..', __dir__), repository: REPOSITORY)
      @root = File.realpath(root)
      @repository = repository
    end

    def validate!
      unless File.exist?(File.join(@root, '.git'))
        raise 'Self-update requires a Git installation. For a gem installation, run: gem update buzzsprout-cli'
      end
      remote = git('remote', 'get-url', 'origin')
      repositories = @repository == REPOSITORY ? [REPOSITORY, LEGACY_REPOSITORY] : [@repository]
      accepted_remotes = repositories.flat_map do |repository|
        [repository, repository.delete_suffix('.git'),
         repository.sub('https://github.com/', 'git@github.com:')]
      end
      unless accepted_remotes.include?(remote)
        raise 'Self-update requires the official buzzsprout/buzzsprout-cli repository.'
      end
      # get-url above expands url.<base>.insteadOf, but fetch uses @repository directly,
      # so a rule matching only that spelling would redirect the fetch past the check.
      unless git('ls-remote', '--get-url', @repository) == @repository
        raise 'Git is rewriting the update URL (url.*.insteadOf). Remove the rewrite before updating.'
      end
      raise 'Self-update requires the main branch. Update development checkouts manually.' unless git('branch', '--show-current') == 'main'
      raise 'Local changes found. Commit or move them before updating; nothing was overwritten.' unless git('status', '--porcelain').empty?
    end

    def check
      validate!
      current = git('rev-parse', 'HEAD')
      latest = latest_commit
      { current_commit: current, latest_commit: latest, update_available: update_available?(current, latest),
        update_command: 'buzzsprout update' }
    end

    def update(io:, dir: nil)
      validate!
      before = git('rev-parse', 'HEAD')
      io.puts 'Checking for updates…'
      expected = latest_commit
      git('fetch', '--no-tags', @repository, 'main')
      target = git('rev-parse', 'FETCH_HEAD')
      unless target == expected
        raise 'Fetched commit does not match the published main commit. Nothing was merged; try again later.'
      end
      validate!
      git('merge-base', '--is-ancestor', 'HEAD', target)
      git('merge', '--ff-only', target)

      # Run the new CLI in a fresh process so skill installation uses the updated code.
      args = [RbConfig.ruby, File.join(@root, 'bin/buzzsprout'), 'skills', 'install']
      args.concat(['--dir', dir]) if dir
      destinations = Commands::Skills.destination_dirs(dir)
      unless destinations.empty?
        stdout, stderr, status = Open3.capture3({ 'BUZZSPROUT_NO_UPDATE_CHECK' => '1' }, *args)
        io.print stdout
        io.print stderr
        raise 'CLI updated, but skills could not be refreshed. Run buzzsprout skills install to retry.' unless status.success?
      end
      { updated: before != target, current_commit: target, skills_refreshed: !destinations.empty? }
    end

    def notify(io:)
      return if ENV['BUZZSPROUT_NO_UPDATE_CHECK'] == '1' || ENV['CI']
      validate!
      path = "#{Config.config_file}.update-check.json"
      FileUtils.mkdir_p(File.dirname(path))
      File.open(path, File::RDWR | File::CREAT, 0o600) do |file|
        return unless file.flock(File::LOCK_EX | File::LOCK_NB)
        cached = JSON.parse(file.read) rescue {}
        if Time.now.to_i - cached.fetch('checked_at', 0).to_i >= INTERVAL
          cached = { 'checked_at' => Time.now.to_i }
          begin
            cached['latest_commit'] = latest_commit
          rescue StandardError
            # Cache failed attempts too, avoiding repeated offline delays.
          end
          file.rewind
          file.truncate(0)
          file.write(JSON.generate(cached))
        end
        latest = cached['latest_commit']
        if latest && update_available?(git('rev-parse', 'HEAD'), latest)
          io.puts 'Buzzsprout CLI update available. Run `buzzsprout update` to update the CLI and agent skills.'
        end
      end
    rescue StandardError
      # Update discovery must never break an API command.
      nil
    end

    private

    def update_available?(current, latest)
      return false if current == latest
      # A cached main commit may already be an ancestor of a newer installation.
      git('merge-base', '--is-ancestor', latest, current)
      false
    rescue RuntimeError
      true
    end

    def latest_commit
      Timeout.timeout(3) do
        uri = URI(ENDPOINT)
        request = Net::HTTP::Get.new(uri)
        request['User-Agent'] = Client::USER_AGENT
        request['Accept'] = 'application/vnd.github+json'
        response = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 2, read_timeout: 2) { |http| http.request(request) }
        raise "Could not check for updates (GitHub HTTP #{response.code}). Try again later." unless response.is_a?(Net::HTTPSuccess)
        sha = JSON.parse(response.body).fetch('sha')
        raise 'Invalid update response from GitHub.' unless sha.is_a?(String) && sha.match?(/\A[0-9a-f]{40}\z/)
        sha
      end
    end

    def git(*args)
      stdout, stderr, status = Open3.capture3({ 'GIT_TERMINAL_PROMPT' => '0' }, 'git', '-C', @root, *args)
      unless status.success?
        raise "Cannot update this installation: #{stderr.strip.empty? ? 'local history cannot be fast-forwarded to main' : stderr.strip}"
      end
      stdout.strip
    end
  end
end

# frozen_string_literal: true

require_relative 'lib/buzzsprout/version'

Gem::Specification.new do |spec|
  spec.name          = 'buzzsprout-cli'
  spec.version       = Buzzsprout::VERSION
  spec.authors       = ['Higher Pixels']
  spec.email         = ['support@buzzsprout.com']

  spec.summary       = 'Command-line interface for the Buzzsprout API'
  spec.description   = 'A fun, agent-friendly CLI for Buzzsprout. Authenticate with an API token, list podcasts and episodes, and call the rest of the API.'
  spec.homepage      = 'https://github.com/higher-pixels/buzzsprout-cli'
  spec.license       = 'MIT'

  spec.required_ruby_version = '>= 3.0.0'

  spec.files         = Dir['lib/**/*', 'bin/*', 'skills/**/*', 'assets/**/*', 'README.md', 'LICENSE']
  spec.bindir        = 'bin'
  spec.executables   = ['buzzsprout']

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = spec.homepage
  spec.metadata['changelog_uri'] = "#{spec.homepage}/releases"
  spec.metadata['rubygems_mfa_required'] = 'true'
end

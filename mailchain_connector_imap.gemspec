# frozen_string_literal: true

require_relative 'lib/mailchain_connector_imap/version'

Gem::Specification.new do |spec|
  spec.name          = 'mailchain_connector_imap'
  spec.version       = MailchainConnectorImap::VERSION
  spec.authors       = ['Tim B']
  spec.email         = ['team@mailchain.xyz']

  spec.summary       = 'An IMAP connector for the Mailchain API'
  spec.description   = 'Send your Mailchain messages to your email inbox with the IMAP connector for the Mailchain API'
  spec.homepage      = 'https://mailchain.xyz/mailchain-connectors/imap'
  spec.required_ruby_version = Gem::Requirement.new('>= 2.3.0')
  spec.license = 'Apache2.0'

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = 'https://github.com/mailchain/mailchain-connector-imap'
  spec.metadata['changelog_uri'] = 'https://github.com/mailchain/mailchain-connector-imap/releases'

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  end
  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_development_dependency 'bundle', '~> 2.0'
  spec.add_development_dependency 'pry', '~> 0.13'
  spec.add_development_dependency 'rake', '~> 12.0'
  spec.add_development_dependency 'rspec', '~> 3.0'

  spec.add_runtime_dependency 'httparty', '~> 0.18', '>= 0.18.0'
  spec.add_runtime_dependency 'mail', '~> 2.7', '>= 2.7.1'
  spec.add_runtime_dependency 'tty-prompt', '~> 0.21', '>= 0.21.0'
end

# frozen_string_literal: true

require_relative 'lib/smart_domain/version'

Gem::Specification.new do |spec|
  spec.name = 'smart_domain'
  spec.version = SmartDomain::VERSION
  spec.authors = ['Rachid Al Maach']
  spec.email = ['rachid@qraft.nl']

  spec.summary = 'Smart Domain-Driven Design and Event-Driven Architecture for Rails'
  spec.description = <<~DESC
    SmartDomain brings battle-tested DDD/EDA patterns to Rails applications.
    Inspired by the Aeyes healthcare platform, it provides domain events,
    event bus, generic handlers, and Rails generators for rapid domain scaffolding.
    Features 70% boilerplate reduction through intelligent event handling and
    AI-augmented development patterns.
  DESC
  spec.homepage = 'https://github.com/rachid/smart_domain'
  spec.license = 'MIT'
  spec.required_ruby_version = '>= 3.0.0'

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = 'https://github.com/rachid/smart_domain'
  spec.metadata['changelog_uri'] = 'https://github.com/rachid/smart_domain/blob/main/CHANGELOG.md'
  spec.metadata['rubygems_mfa_required'] = 'true'

  spec.files = Dir.chdir(__dir__) do
    `git ls-files -z`.split("\x0").reject do |f|
      (File.expand_path(f) == __FILE__) ||
        f.start_with?(*%w[bin/ test/ spec/ features/ .git .github appveyor Gemfile])
    end
  end

  spec.bindir = 'exe'
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  # Core dependencies
  spec.add_dependency 'activemodel', '>= 7.0'
  spec.add_dependency 'activerecord', '>= 7.0'
  spec.add_dependency 'activesupport', '>= 7.0'
  spec.add_dependency 'rails', '>= 7.0'

  # Development dependencies
  spec.add_development_dependency 'factory_bot_rails', '~> 6.2'
  spec.add_development_dependency 'faker', '~> 3.2'
  spec.add_development_dependency 'rspec', '~> 3.12'
  spec.add_development_dependency 'rspec-rails', '~> 6.0'
  spec.add_development_dependency 'rubocop', '~> 1.50'
  spec.add_development_dependency 'rubocop-rails', '~> 2.19'
  spec.add_development_dependency 'rubocop-rspec', '~> 2.20'
  spec.add_development_dependency 'sqlite3', '>= 2.1'
end

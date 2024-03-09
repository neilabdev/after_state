# frozen_string_literal: true

require_relative "lib/after_state/version"

Gem::Specification.new do |spec|
  spec.name = "after_state"
  spec.version = AfterState::VERSION
  spec.authors = ["James Whitfield"]
  spec.email = ["2140679+neilabdev@users.noreply.github.com"]

  spec.summary = "Allows setting callbacks for state changes on Active Models"
  spec.description = "Allows setting callbacks for state changes on Active Models"
  spec.homepage = "https://github.com/neilabdev/after_state"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 2.6.0"

  spec.metadata["allowed_push_host"] = "TODO: Set to your gem server 'https://example.com'"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/neilabdev/after_state"
  spec.metadata["changelog_uri"] = "https://github.com/neilabdev/after_state/blob/master/CHANGELOG.md"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(__dir__) do
    `git ls-files -z`.split("\x0").reject do |f|
      (File.expand_path(f) == __FILE__) || f.start_with?(*%w[bin/ test/ spec/ features/ .git .circleci appveyor])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency 'activesupport', '>= 6.1'
  spec.add_dependency 'actionpack', '>= 6.1'
  spec.add_dependency 'activemodel', '>= 6.1'
  spec.add_dependency "railties", ">= 6.1"

  # For more information and examples about making a new gem, check out our
  # guide at: https://bundler.io/guides/creating_gem.html
end

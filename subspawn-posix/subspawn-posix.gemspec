# frozen_string_literal: true

require_relative "lib/subspawn/posix/version"

Gem::Specification.new do |spec|
  spec.name = "subspawn-posix"
  spec.version = SubSpawn::POSIX::VERSION
  spec.authors = ["Patrick Plenefisch"]
  spec.email = ["simonpatp@gmail.com"]

  spec.summary = "SubSpawn Mid-level API for POSIX systems"
  spec.description = "A SubSpawn subproject to wrap libfixposix as a mid level API"
  final_github = "https://github.com/byteit101/subspawn"
  spec.homepage = final_github
  spec.required_ruby_version = ">= 2.6.0"

  #spec.metadata["allowed_push_host"] = "TODO: Set to your gem server 'https://example.com'"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = final_github
  spec.metadata["changelog_uri"] = final_github

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(__dir__) do
    `git ls-files -z`.split("\x0").reject do |f|
      (f == __FILE__) || f.match(%r{\A(?:(?:bin|test|spec|features)/|\.(?:git|travis|circleci)|appveyor)})
    end
  end
  spec.require_paths = ["lib"]

  # Uncomment to register a new dependency of your gem
  spec.add_dependency "subspawn-common", "~> 0.2.0.pre1"
  spec.add_dependency "ffi-bindings-libfixposix", "~> 0.5.0"

  # For more information and examples about making a new gem, check out our
  # guide at: https://bundler.io/guides/creating_gem.html

  # You can use Ruby's license, or any of the JRuby tri-license options
  spec.licenses = ["Ruby", "EPL-2.0", "LGPL-2.1-or-later"]
end

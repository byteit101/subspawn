# frozen_string_literal: true

require_relative "lib/libfixposix/version"

Gem::Specification.new do |spec|
  spec.name = "ffi-bindings-libfixposix"
  spec.version = LFP::VERSION
  spec.authors = ["Patrick Plenefisch"]
  spec.email = ["simonpatp@gmail.com"]

  spec.summary = "Direct FFI bindings for libfixposix"
  spec.description = "Direct FFI bindings for libfixposix. Binary not included."
  final_github = "https://github.com/jruby/subspawn"
  spec.homepage = final_github
  spec.required_ruby_version = ">= 2.6.0"

  spec.metadata["allowed_push_host"] = "TODO: Set to your gem server 'https://example.com'"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = final_github
  spec.metadata["changelog_uri"] = final_github

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(__dir__) do
    `git ls-files -z`.split("\x0").reject do |f|
      (f == __FILE__) || f.match(%r{\A(?:(?:bin|test|spec|features)/|\.(?:git|travis|circleci)|appveyor)})
    end + ["lib/libfixposix/ffi.rb"]
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "ffi", ">= 1.15"

  # For more information and examples about making a new gem, check out our
  # guide at: https://bundler.io/guides/creating_gem.html
end

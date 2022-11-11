# frozen_string_literal: true

require_relative "lib/libfixposix/binary/version"

Gem::Specification.new do |spec|
  spec.name = "ffi-binary-libfixposix"
  spec.version = LFP::Binary::GEM_VERSION
  spec.authors = ["Patrick Plenefisch"]
  spec.email = ["simonpatp@gmail.com"]

  # we build on each platform
  spec.platform = Gem::Platform.local

  spec.summary = "Pre-built libfixposix binaries"
  spec.description = "Pre-built libfixposix binaries for use with ffi-bindings-libfixposix. Part of the SubSpawn Project"
  final_github = "https://github.com/byteit101/subspawn"
  spec.homepage = final_github
  spec.required_ruby_version = ">= 2.6.0"

  #spec.metadata["allowed_push_host"] = "TODO: Set to your gem server 'https://example.com'"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = final_github
  spec.metadata["changelog_uri"] = final_github

  # Specify which files should be added to the gem when it is released.
  spec.files = %W{.rb /version.rb /libfixposix.#{spec.platform.to_s.include?("darwin")? "dylib" : "so"}}.map{|x|"lib/libfixposix/binary#{x}"}
  spec.require_paths = ["lib"]

  # Uncomment to register a new dependency of your gem
  spec.add_dependency "ffi", "~> 1.0"
  #spec.add_dependency "ffi-bindings-libfixposix", "~> #{LFP::Binary::GEM_VERSION}"

  # For more information and examples about making a new gem, check out our
  # guide at: https://bundler.io/guides/creating_gem.html
end

# frozen_string_literal: true

require_relative "lib/mockit/version"

Gem::Specification.new do |spec|
  spec.name = "mockit"
  spec.version = Mockit::VERSION
  spec.authors = ["Ivan Neverov"]
  spec.email = ["ivan.neverov@gmail.com"]

  spec.summary = "Mock infrastructure with per-request control using headers"
  spec.description = <<-DESCRIPTION
    Allows mocking external services per-request using X-Mockit-Id headers. Works with Sidekiq."
  DESCRIPTION
  spec.homepage = "http://rubygems.org"

  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.1.0"

  spec.metadata["allowed_push_host"] = "TODO: Set to your gem server 'https://example.com'"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "http://rubygems.org"
  spec.metadata["changelog_uri"] = "http://google.com"
  spec.metadata["rubygems_mfa_required"] = "true"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[test/ spec/ features/ .git .github appveyor Gemfile])
    end
  end
  spec.require_paths = ["lib"]

  spec.add_dependency "rails", ">= 6.0"
  spec.add_dependency "request_store"
end

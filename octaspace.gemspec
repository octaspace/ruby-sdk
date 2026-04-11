# frozen_string_literal: true

require_relative "lib/octaspace/version"

Gem::Specification.new do |spec|
  spec.name        = "octaspace"
  spec.version     = OctaSpace::VERSION
  spec.authors     = ["OctaSpace Team"]
  spec.email       = ["dev@octa.space"]

  spec.summary     = "Ruby SDK for the OctaSpace API"
  spec.description = "Official Ruby client for the OctaSpace API. Supports keep-alive " \
                     "connections, URL rotation/failover, retry with exponential backoff, " \
                     "and optional Rails integration."
  spec.homepage    = "https://github.com/octaspace/ruby-sdk"
  spec.license     = "MIT"

  spec.required_ruby_version = ">= 3.1"

  spec.metadata = {
    "homepage_uri"          => spec.homepage,
    "changelog_uri"         => "#{spec.homepage}/blob/main/CHANGELOG.md",
    "source_code_uri"       => spec.homepage,
    "bug_tracker_uri"       => "#{spec.homepage}/issues",
    "rubygems_mfa_required" => "true"
  }

  # Only ship lib/, LICENSE, README, CHANGELOG — not test/ or docs/
  spec.files = Dir[
    "lib/**/*",
    "MIT-LICENSE",
    "README.md",
    "CHANGELOG.md"
  ]

  spec.require_paths = ["lib"]

  # --- Runtime dependencies (keep minimal) ---
  spec.add_dependency "faraday",       "~> 2.9"
  spec.add_dependency "faraday-retry", "~> 2.2"

  # Optional runtime (persistent mode) — users add to their own Gemfile:
  #   gem "faraday-net_http_persistent"
  #   gem "connection_pool"
end

$LOAD_PATH.push File.expand_path("lib", __dir__)

require "octaspace/version"

Gem::Specification.new do |spec|
  spec.name = "octaspace"
  spec.version = OctaSpace::VERSION
  spec.authors = ["OctaSpace Team"]
  spec.email = ["dev@octa.space"]

  spec.summary = "Ruby SDK for the OctaSpace API"
  spec.description = "Official Ruby client for OctaSpace. " \
                     "Keep-alive connections, URL failover, retry with backoff, Rails integration."
  spec.homepage = "https://github.com/octaspace/ruby-sdk"
  spec.license = "MIT"

  spec.required_ruby_version = ">= 3.2.0"

  spec.metadata = {
    "changelog_uri" => "#{spec.homepage}/blob/main/CHANGELOG.md",
    "source_code_uri" => spec.homepage,
    "bug_tracker_uri" => "#{spec.homepage}/issues",
    "rubygems_mfa_required" => "true"
  }

  spec.files = Dir["lib/**/*", "MIT-LICENSE", "README.md", "CHANGELOG.md"] -
    Dir["lib/octaspace/playground/**/*", "lib/octaspace/transport/mock_transport.rb", "lib/octaspace/engine.rb"]
  spec.require_paths = ["lib"]

  spec.add_dependency "faraday", "~> 2.9"
  spec.add_dependency "faraday-retry", "~> 2.2"

  # Optional — persistent mode (users add to their own Gemfile):
  #   gem "faraday-net_http_persistent"
  #   gem "connection_pool"
end

$LOAD_PATH.push File.expand_path("lib", __dir__)

require "octaspace/version"

Gem::Specification.new do |spec|
  spec.name = "octaspace"
  spec.version = OctaSpace::VERSION
  spec.authors = ["OctaSpace Team"]
  spec.email = ["dev@octa.space"]

  spec.summary = "Official Ruby library for the OctaSpace API"
  spec.description = "Rent compute machines and render nodes, manage sessions and the nodes " \
                     "you host, and read GPU market statistics on OctaSpace from Ruby code."
  spec.homepage = "https://github.com/octaspace/ruby-sdk"
  spec.license = "MIT"

  spec.required_ruby_version = ">= 3.3.0"

  spec.metadata = {
    "changelog_uri" => "#{spec.homepage}/blob/v#{spec.version}/CHANGELOG.md",
    "documentation_uri" => "https://rubydoc.info/gems/octaspace/#{spec.version}",
    "source_code_uri" => spec.homepage,
    "bug_tracker_uri" => "#{spec.homepage}/issues",
    "rubygems_mfa_required" => "true"
  }

  spec.files = Dir["lib/**/*.rb", "LICENSE", "README.md", "CHANGELOG.md"]
  spec.require_paths = ["lib"]

  spec.add_dependency "faraday", ">= 2.14.3", "< 3"

  # Optional — persistent mode (users add to their own Gemfile):
  #   gem "faraday-net_http_persistent"
  #   gem "connection_pool"
end

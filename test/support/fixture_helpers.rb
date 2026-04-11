# frozen_string_literal: true

module FixtureHelpers
  FIXTURE_PATH = File.expand_path("../fixtures", __dir__)

  # Load a JSON fixture file and return its content as a String
  # @param path [String] relative path under test/fixtures/ (e.g. "nodes/index.json")
  # @return [String]
  def fixture(path)
    full_path = File.join(FIXTURE_PATH, path)
    raise "Fixture not found: #{full_path}" unless File.exist?(full_path)
    File.read(full_path)
  end

  # JSON content-type headers
  # @return [Hash]
  def json_headers
    {"Content-Type" => "application/json"}
  end
end

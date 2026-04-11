# frozen_string_literal: true

require "webmock/minitest"

module StubHelpers
  BASE_URL = "https://api.octa.space"

  # Stub a successful GET request
  # @param path [String] API path (e.g. "/nodes")
  # @param fixture_path [String] path under test/fixtures/
  # @param status [Integer]
  def stub_get(path, fixture_path:, status: 200)
    stub_request(:get, "#{BASE_URL}#{path}")
      .to_return(
        status:  status,
        body:    fixture(fixture_path),
        headers: json_headers
      )
  end

  # Stub a POST request
  # @param path [String]
  # @param fixture_path [String]
  # @param status [Integer]
  def stub_post(path, fixture_path: nil, status: 200, body: nil)
    stub_request(:post, "#{BASE_URL}#{path}")
      .to_return(
        status:  status,
        body:    fixture_path ? fixture(fixture_path) : (body || "{}"),
        headers: json_headers
      )
  end

  # Stub an error response
  # @param method [Symbol]
  # @param path [String]
  # @param status [Integer]
  # @param message [String]
  def stub_error(method, path, status:, message: "Error")
    stub_request(method, "#{BASE_URL}#{path}")
      .to_return(
        status:  status,
        body:    {error: message}.to_json,
        headers: json_headers
      )
  end

  # Build a test client with a fixed API key
  # @return [OctaSpace::Client]
  def test_client(api_key: "test_key_123", **opts)
    OctaSpace::Client.new(api_key: api_key, **opts)
  end
end

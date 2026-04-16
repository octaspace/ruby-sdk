# frozen_string_literal: true

require "test_helper"

class OctaSpace::SessionsResourceTest < Minitest::Test
  def setup
    super
    @client = test_client
  end

  def test_list_returns_array
    stub_get("/sessions", fixture_path: "sessions/index.json")
    response = @client.sessions.list
    assert response.success?
    assert_kind_of Array, response.data
    assert_equal "sess-abc-123", response.data.first["uuid"]
  end

  def test_list_passes_params
    stub_request(:get, "#{StubHelpers::BASE_URL}/sessions")
      .with(query: {"recent" => "true"})
      .to_return(status: 200, body: fixture("sessions/recent.json"), headers: json_headers)
    response = @client.sessions.list(recent: true)
    assert response.success?
    assert_equal "28", response.data.first["duration"]
    assert_equal "0", response.data.first["rx"]
  end

  def test_list_raises_authentication_error_on_401
    stub_error(:get, "/sessions", status: 401, message: "Unauthorized")
    assert_raises(OctaSpace::AuthenticationError) { @client.sessions.list }
  end
end

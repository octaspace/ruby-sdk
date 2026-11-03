# frozen_string_literal: true

require "test_helper"

class OctaSpace::ServicesResourceTest < Minitest::Test
  def setup
    super
    @client = test_client
  end

  # --- SessionProxy ---

  def test_session_proxy_info
    stub_get("/services/sess-abc-123/info", fixture_path: "services/session/info.json")
    response = @client.services.session("sess-abc-123").info
    assert response.success?
    assert_equal "sess-abc-123", response.data["uuid"]
    assert_equal "running", response.data["status"]
  end

  def test_session_proxy_logs
    stub_get("/services/sess-abc-123/logs", fixture_path: "services/session/logs.json")
    response = @client.services.session("sess-abc-123").logs
    assert response.success?
    assert_kind_of Hash, response.data
    assert_kind_of Array, response.data["system"]
  end

  def test_session_proxy_logs_with_recent_flag
    stub_request(:get, "#{StubHelpers::BASE_URL}/services/sess-abc-123/logs")
      .with(query: {"recent" => "true"})
      .to_return(status: 200, body: fixture("services/session/logs.json"), headers: json_headers)

    response = @client.services.session("sess-abc-123").logs(recent: true)
    assert response.success?
    assert_equal "", response.data["container"]
  end

  def test_session_proxy_stop
    stub_post("/services/sess-abc-123/stop", status: 200, body: '{"status":"stopped"}')
    response = @client.services.session("sess-abc-123").stop(score: 5)
    assert response.success?
  end

  def test_session_proxy_stop_without_params
    stub_post("/services/sess-abc-123/stop", status: 200, body: '{"status":"stopped"}')
    response = @client.services.session("sess-abc-123").stop
    assert response.success?
  end

  def test_session_proxy_raises_not_found
    stub_error(:get, "/services/bad-uuid/info", status: 404, message: "Session not found")
    assert_raises(OctaSpace::NotFoundError) { @client.services.session("bad-uuid").info }
  end
end

# frozen_string_literal: true

require "test_helper"

class OctaSpace::FaradayTransportTest < Minitest::Test
  BASE = StubHelpers::BASE_URL

  def setup
    super
    @config = OctaSpace::Configuration.new
    @config.api_key = "test_key"
    @config.max_retries = 0
    @transport = OctaSpace::Transport::FaradayTransport.new(@config)
  end

  # --- Basic HTTP verbs ---

  def test_get_returns_response
    stub_request(:get, "#{BASE}/nodes")
      .to_return(status: 200, body: "[]", headers: {"Content-Type" => "application/json"})
    response = @transport.get("/nodes")
    assert_instance_of OctaSpace::Response, response
    assert response.success?
  end

  def test_post_returns_response
    stub_request(:post, "#{BASE}/idle-jobs")
      .to_return(status: 201, body: '{"id":1}', headers: {"Content-Type" => "application/json"})
    response = @transport.post("/idle-jobs", body: {command: "sleep 1"})
    assert response.success?
  end

  def test_put_returns_response
    stub_request(:put, "#{BASE}/nodes/1/prices")
      .to_return(status: 200, body: "{}", headers: {"Content-Type" => "application/json"})
    response = @transport.put("/nodes/1/prices", body: {gpu_hour: 0.5})
    assert response.success?
  end

  def test_delete_returns_response
    stub_request(:delete, "#{BASE}/idle-jobs/1")
      .to_return(status: 200, body: "{}", headers: {"Content-Type" => "application/json"})
    response = @transport.delete("/idle-jobs/1")
    assert response.success?
  end

  # --- Authorization header ---

  def test_sends_authorization_header
    stub_request(:get, "#{BASE}/nodes")
      .with(headers: {"Authorization" => "test_key"})
      .to_return(status: 200, body: "[]", headers: {"Content-Type" => "application/json"})
    @transport.get("/nodes")
    # WebMock raises if header doesn't match — reaching here means it did
    assert true
  end

  # --- Error mapping ---

  def test_raises_authentication_error_on_401
    stub_request(:get, "#{BASE}/accounts")
      .to_return(status: 401, body: '{"error":"Unauthorized"}',
        headers: {"Content-Type" => "application/json"})
    assert_raises(OctaSpace::AuthenticationError) { @transport.get("/accounts") }
  end

  def test_raises_permission_error_on_403
    stub_request(:get, "#{BASE}/accounts")
      .to_return(status: 403, body: '{"error":"Forbidden"}',
        headers: {"Content-Type" => "application/json"})
    assert_raises(OctaSpace::PermissionError) { @transport.get("/accounts") }
  end

  def test_raises_not_found_error_on_404
    stub_request(:get, "#{BASE}/nodes/99")
      .to_return(status: 404, body: '{"error":"Not found"}',
        headers: {"Content-Type" => "application/json"})
    assert_raises(OctaSpace::NotFoundError) { @transport.get("/nodes/99") }
  end

  def test_raises_validation_error_on_422
    stub_request(:post, "#{BASE}/idle-jobs")
      .to_return(status: 422, body: '{"error":"Invalid params"}',
        headers: {"Content-Type" => "application/json"})
    assert_raises(OctaSpace::ValidationError) { @transport.post("/idle-jobs", body: {}) }
  end

  def test_raises_rate_limit_error_on_429_with_retry_after
    stub_request(:get, "#{BASE}/nodes")
      .to_return(status: 429, body: "{}",
        headers: {"Content-Type" => "application/json", "Retry-After" => "30"})
    error = assert_raises(OctaSpace::RateLimitError) { @transport.get("/nodes") }
    assert_equal 30, error.retry_after
  end

  def test_retries_on_429_then_raises_after_exhaustion
    # Enable retry with Retry-After: 0 so sleep is instant
    @config.max_retries = 1
    transport = OctaSpace::Transport::FaradayTransport.new(@config)
    stub_request(:get, "#{BASE}/nodes")
      .to_return(status: 429, body: "{}",
        headers: {"Content-Type" => "application/json", "Retry-After" => "0"})
    assert_raises(OctaSpace::RateLimitError) { transport.get("/nodes") }
    assert_requested :get, "#{BASE}/nodes", times: 2
  end

  def test_raises_server_error_on_500
    stub_request(:get, "#{BASE}/nodes")
      .to_return(status: 500, body: '{"error":"Internal Server Error"}',
        headers: {"Content-Type" => "application/json"})
    assert_raises(OctaSpace::ServerError) { @transport.get("/nodes") }
  end

  def test_raises_bad_gateway_error_on_502
    stub_request(:get, "#{BASE}/nodes")
      .to_return(status: 502, body: "{}", headers: {"Content-Type" => "application/json"})
    assert_raises(OctaSpace::BadGatewayError) { @transport.get("/nodes") }
  end

  def test_raises_service_unavailable_on_503
    stub_request(:get, "#{BASE}/nodes")
      .to_return(status: 503, body: "{}", headers: {"Content-Type" => "application/json"})
    assert_raises(OctaSpace::ServiceUnavailableError) { @transport.get("/nodes") }
  end

  def test_raises_gateway_timeout_on_504
    stub_request(:get, "#{BASE}/nodes")
      .to_return(status: 504, body: "{}", headers: {"Content-Type" => "application/json"})
    assert_raises(OctaSpace::GatewayTimeoutError) { @transport.get("/nodes") }
  end

  # --- Network errors ---

  def test_raises_connection_error_on_connection_failed
    stub_request(:get, "#{BASE}/nodes").to_raise(Faraday::ConnectionFailed.new("Connection refused"))
    assert_raises(OctaSpace::ConnectionError) { @transport.get("/nodes") }
  end

  def test_raises_timeout_error_on_timeout
    stub_request(:get, "#{BASE}/nodes").to_raise(Faraday::TimeoutError.new("timeout"))
    assert_raises(OctaSpace::TimeoutError) { @transport.get("/nodes") }
  end

  # --- Hooks ---

  def test_on_request_hook_is_called
    called_with = nil
    @config.on_request = ->(ctx) { called_with = ctx }
    stub_request(:get, "#{BASE}/nodes")
      .to_return(status: 200, body: "[]", headers: {"Content-Type" => "application/json"})
    @transport.get("/nodes")
    assert_equal :get, called_with[:method]
    assert_equal "/nodes", called_with[:path]
  end

  def test_on_response_hook_is_called
    called_with = nil
    @config.on_response = ->(resp) { called_with = resp }
    stub_request(:get, "#{BASE}/nodes")
      .to_return(status: 200, body: "[]", headers: {"Content-Type" => "application/json"})
    @transport.get("/nodes")
    assert_instance_of OctaSpace::Response, called_with
    assert_equal 200, called_with.status
  end

  # --- URL rotation / failover ---

  def test_url_rotation_with_multiple_base_urls
    @config.base_urls = ["https://api.octa.space", "https://api2.octa.space"]
    transport = OctaSpace::Transport::FaradayTransport.new(@config)

    stub_request(:get, "https://api.octa.space/nodes")
      .to_return(status: 200, body: "[]", headers: {"Content-Type" => "application/json"})
    stub_request(:get, "https://api2.octa.space/nodes")
      .to_return(status: 200, body: "[]", headers: {"Content-Type" => "application/json"})

    # Both calls should succeed (rotator picks one)
    resp1 = transport.get("/nodes")
    resp2 = transport.get("/nodes")
    assert resp1.success?
    assert resp2.success?
  end

  def test_failover_to_second_url_on_connection_error
    @config.base_urls = ["https://bad.octa.space", "https://api.octa.space"]
    transport = OctaSpace::Transport::FaradayTransport.new(@config)

    stub_request(:get, "https://bad.octa.space/nodes")
      .to_raise(Faraday::ConnectionFailed.new("refused"))
    stub_request(:get, "https://api.octa.space/nodes")
      .to_return(status: 200, body: "[]", headers: {"Content-Type" => "application/json"})

    response = transport.get("/nodes")
    assert response.success?
  end

  def test_raises_connection_error_when_all_urls_fail
    @config.base_urls = ["https://bad1.octa.space", "https://bad2.octa.space"]
    transport = OctaSpace::Transport::FaradayTransport.new(@config)

    stub_request(:get, "https://bad1.octa.space/nodes")
      .to_raise(Faraday::ConnectionFailed.new("refused"))
    stub_request(:get, "https://bad2.octa.space/nodes")
      .to_raise(Faraday::ConnectionFailed.new("refused"))

    assert_raises(OctaSpace::ConnectionError) { transport.get("/nodes") }
  end

  # --- Query params ---

  def test_get_passes_query_params
    stub_request(:get, "#{BASE}/nodes")
      .with(query: {"state" => "online", "limit" => "10"})
      .to_return(status: 200, body: "[]", headers: {"Content-Type" => "application/json"})
    response = @transport.get("/nodes", params: {state: "online", limit: 10})
    assert response.success?
  end
end

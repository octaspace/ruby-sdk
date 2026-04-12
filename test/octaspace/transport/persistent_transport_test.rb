# frozen_string_literal: true

require "test_helper"

class OctaSpace::PersistentTransportTest < Minitest::Test
  BASE = StubHelpers::BASE_URL

  def setup
    super
    require "faraday/net_http_persistent"
    require "connection_pool"
    require "octaspace/transport/persistent_transport"

    @config = OctaSpace::Configuration.new
    @config.api_key = "test_key"
    @config.keep_alive = true
    @config.max_retries = 0
    @config.pool_size = 2
    @transport = OctaSpace::Transport::PersistentTransport.new(@config)
  end

  def teardown
    @transport.shutdown
  end

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

  def test_pool_stats_returns_hash
    stats = @transport.pool_stats
    assert_kind_of Hash, stats
  end

  def test_pool_stats_includes_url_key_after_request
    stub_request(:get, "#{BASE}/nodes")
      .to_return(status: 200, body: "[]", headers: {"Content-Type" => "application/json"})
    @transport.get("/nodes")
    stats = @transport.pool_stats
    assert stats.key?(BASE), "Expected pool stats to contain key for #{BASE}"
  end

  def test_shutdown_clears_pools
    stub_request(:get, "#{BASE}/nodes")
      .to_return(status: 200, body: "[]", headers: {"Content-Type" => "application/json"})
    @transport.get("/nodes")
    @transport.shutdown
    # After shutdown, pools should be empty
    assert_equal({}, @transport.pool_stats)
  end

  def test_raises_not_found_error_on_404
    stub_request(:get, "#{BASE}/nodes/99")
      .to_return(status: 404, body: '{"error":"Not found"}',
        headers: {"Content-Type" => "application/json"})
    assert_raises(OctaSpace::NotFoundError) { @transport.get("/nodes/99") }
  end

  def test_raises_authentication_error_on_401
    stub_request(:get, "#{BASE}/accounts")
      .to_return(status: 401, body: '{"error":"Unauthorized"}',
        headers: {"Content-Type" => "application/json"})
    assert_raises(OctaSpace::AuthenticationError) { @transport.get("/accounts") }
  end

  def test_sends_authorization_header
    stub_request(:get, "#{BASE}/nodes")
      .with(headers: {"Authorization" => "test_key"})
      .to_return(status: 200, body: "[]", headers: {"Content-Type" => "application/json"})
    @transport.get("/nodes")
    assert true
  end
end

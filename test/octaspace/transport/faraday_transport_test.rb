# frozen_string_literal: true

require "test_helper"
require "logger"
require "stringio"

class OctaSpace::FaradayTransportTest < Minitest::Test
  BASE = StubHelpers::BASE_URL
  KEY = "octa_ak_testkey"
  JSON_HEADERS = {"Content-Type" => "application/json"}.freeze

  def setup
    super
    @sleeps = []
    @config = OctaSpace::Configuration.new
    @config.api_key = KEY
    @config.max_retries = 0
  end

  def transport(config = @config)
    OctaSpace::Transport::FaradayTransport.new(config, sleeper: ->(s) { @sleeps << s })
  end

  # --- Requests ---

  def test_get_parses_json_body
    stub_request(:get, "#{BASE}/sessions").to_return(status: 200, body: '[{"uuid":"a"}]', headers: JSON_HEADERS)
    response = transport.get("/sessions")

    assert_instance_of OctaSpace::Response, response
    assert_equal [{"uuid" => "a"}], response.data
  end

  def test_post_sends_json_body
    stub_request(:post, "#{BASE}/services/compute")
      .with(body: '{"node_number":"M95S-WZG8-7"}', headers: {"Content-Type" => "application/json"})
      .to_return(status: 201, body: '{"uuid":"u"}', headers: JSON_HEADERS)

    assert_equal "u", transport.post("/services/compute", body: {node_number: "M95S-WZG8-7"}).data["uuid"]
  end

  def test_empty_body_on_204_and_202
    stub_request(:patch, "#{BASE}/hosting/nodes/X/prices").to_return(status: 204, body: "")
    stub_request(:post, "#{BASE}/services/u/stop").to_return(status: 202, body: "")

    assert_nil transport.patch("/hosting/nodes/X/prices", body: {base: 100}).data
    assert_nil transport.post("/services/u/stop").data
  end

  def test_get_drops_nil_query_params
    stub_request(:get, "#{BASE}/services/u/logs").with(query: {"tail" => "10"}).to_return(status: 200, body: "{}")
    assert transport.get("/services/u/logs", params: {tail: 10, recent: nil}).success?
  end

  def test_base_url_path_prefix_is_kept
    @config.base_url = "https://proxy.example/octa/"
    stub_request(:get, "https://proxy.example/octa/network").to_return(status: 200, body: "{}")

    assert transport.get("/network", auth: :none).success?
  end

  def test_invalid_json_on_success_raises_api_error
    stub_request(:get, "#{BASE}/network").to_return(status: 200, body: "<html>portal</html>")

    error = assert_raises(OctaSpace::ApiError) { transport.get("/network", auth: :none) }
    assert_includes error.message, "not valid JSON"
    assert_equal 200, error.status
  end

  # --- Authorization ---

  def test_sends_bearer_authorization
    stub_request(:get, "#{BASE}/accounts/balance")
      .with(headers: {"Authorization" => "Bearer #{KEY}"})
      .to_return(status: 200, body: "{}")

    assert transport.get("/accounts/balance").success?
  end

  def test_pasted_bearer_prefix_is_not_doubled
    @config.api_key = "  Bearer #{KEY} "
    stub_request(:get, "#{BASE}/accounts/balance")
      .with(headers: {"Authorization" => "Bearer #{KEY}"})
      .to_return(status: 200, body: "{}")

    assert transport.get("/accounts/balance").success?
  end

  def test_required_auth_without_key_raises_before_request
    @config.api_key = nil

    error = assert_raises(OctaSpace::AuthenticationError) { transport.get("/sessions") }
    assert_includes error.message, "api_key is required for GET /sessions"
    assert_not_requested :get, "#{BASE}/sessions"
  end

  def test_optional_auth_sends_key_when_present_and_skips_without
    stub_request(:get, "#{BASE}/services/compute").to_return(status: 200, body: "[]")

    transport.get("/services/compute", auth: :optional)
    assert_requested :get, "#{BASE}/services/compute", headers: {"Authorization" => "Bearer #{KEY}"}

    @config.api_key = nil
    transport.get("/services/compute", auth: :optional)
    assert_requested(:get, "#{BASE}/services/compute", times: 1) { |req| !req.headers.key?("Authorization") }
  end

  def test_auth_none_never_sends_key
    stub_request(:get, "#{BASE}/network").to_return(status: 200, body: "{}")
    transport.get("/network", auth: :none)

    assert_requested(:get, "#{BASE}/network") { |req| !req.headers.key?("Authorization") }
  end

  def test_401_with_non_octa_ak_key_adds_hint
    @config.api_key = "a" * 64
    stub_request(:get, "#{BASE}/accounts/balance").to_return(status: 401, body: '{"message":"Invalid bearer token"}')

    error = assert_raises(OctaSpace::AuthenticationError) { transport.get("/accounts/balance") }
    assert_match(/\AInvalid bearer token \(API keys start with "octa_ak_"/, error.message)
  end

  def test_401_with_new_key_has_no_hint
    stub_request(:get, "#{BASE}/accounts/balance").to_return(status: 401, body: '{"message":"Invalid bearer token"}')

    error = assert_raises(OctaSpace::AuthenticationError) { transport.get("/accounts/balance") }
    assert_equal "Invalid bearer token", error.message
  end

  # --- Error mapping ---

  {
    400 => OctaSpace::ValidationError,
    401 => OctaSpace::AuthenticationError,
    403 => OctaSpace::PermissionError,
    404 => OctaSpace::NotFoundError,
    409 => OctaSpace::ConflictError,
    422 => OctaSpace::ValidationError,
    429 => OctaSpace::RateLimitError,
    500 => OctaSpace::ServerError,
    502 => OctaSpace::BadGatewayError,
    503 => OctaSpace::ServiceUnavailableError,
    504 => OctaSpace::GatewayTimeoutError,
    418 => OctaSpace::ApiError
  }.each do |status, klass|
    define_method(:"test_status_#{status}_raises_#{klass.name.split("::").last}") do
      stub_request(:get, "#{BASE}/sessions").to_return(status: status, body: '{"message":"boom"}')

      error = assert_raises(klass) { transport.get("/sessions") }
      assert_equal status, error.status
      assert_equal "boom", error.message
      assert_equal({"message" => "boom"}, error.body)
    end
  end

  def test_error_message_falls_back_to_text_and_is_truncated
    stub_request(:get, "#{BASE}/sessions").to_return(status: 502, body: "x" * 600)

    error = assert_raises(OctaSpace::BadGatewayError) { transport.get("/sessions") }
    assert_equal 513, error.message.length
  end

  def test_error_carries_retry_after_rate_limit_and_request_id
    stub_request(:post, "#{BASE}/services/compute/u/restart").to_return(
      status: 429,
      body: '{"message":"Session was restarted too recently, retry in 288 seconds"}',
      headers: {"Retry-After" => "288", "RateLimit-Limit" => "10", "RateLimit-Remaining" => "6",
                "RateLimit-Reset" => "41", "X-Request-Id" => "req-1"}
    )

    error = assert_raises(OctaSpace::RateLimitError) { transport.post("/services/compute/u/restart") }
    assert_equal 288, error.retry_after
    assert_equal OctaSpace::RateLimit.new(limit: 10, remaining: 6, reset: 41), error.rate_limit
    assert_equal "req-1", error.request_id
  end

  # --- Rate limit state ---

  def test_rate_limit_from_last_response
    t = transport
    assert_nil t.rate_limit

    stub_request(:get, "#{BASE}/sessions").to_return(status: 200, body: "[]",
      headers: {"RateLimit-Limit" => "300", "RateLimit-Remaining" => "299", "RateLimit-Reset" => "60"})
    t.get("/sessions")

    assert_equal 299, t.rate_limit.remaining
  end

  # --- Retries ---

  def test_get_retries_on_503_with_backoff
    @config.max_retries = 2
    stub_request(:get, "#{BASE}/network")
      .to_return({status: 503, body: "{}"}, {status: 503, body: "{}"}, {status: 200, body: "{}"})

    assert transport.get("/network", auth: :none).success?
    assert_equal 2, @sleeps.size
    assert(@sleeps.all? { |s| s.between?(0, @config.max_retry_interval) })
  end

  def test_get_retry_honours_retry_after
    @config.max_retries = 1
    stub_request(:get, "#{BASE}/network")
      .to_return({status: 429, body: "{}", headers: {"Retry-After" => "7"}}, {status: 200, body: "{}"})

    transport.get("/network", auth: :none)
    assert_equal [7], @sleeps
  end

  def test_long_retry_after_is_raised_not_waited
    @config.max_retries = 3
    stub_request(:get, "#{BASE}/network").to_return(status: 429, body: "{}", headers: {"Retry-After" => "300"})

    error = assert_raises(OctaSpace::RateLimitError) { transport.get("/network", auth: :none) }
    assert_equal 300, error.retry_after
    assert_empty @sleeps
    assert_requested :get, "#{BASE}/network", times: 1
  end

  def test_retries_stop_after_max_retries
    @config.max_retries = 1
    stub_request(:get, "#{BASE}/network").to_return(status: 429, body: "{}", headers: {"Retry-After" => "0"})

    assert_raises(OctaSpace::RateLimitError) { transport.get("/network", auth: :none) }
    assert_requested :get, "#{BASE}/network", times: 2
  end

  def test_get_retries_network_errors
    @config.max_retries = 1
    stub_request(:get, "#{BASE}/network")
      .to_raise(Faraday::ConnectionFailed.new("refused")).then
      .to_return(status: 200, body: "{}")

    assert transport.get("/network", auth: :none).success?
  end

  def test_client_errors_are_not_retried
    @config.max_retries = 2
    stub_request(:get, "#{BASE}/sessions").to_return(status: 404, body: "{}")

    assert_raises(OctaSpace::NotFoundError) { transport.get("/sessions") }
    assert_requested :get, "#{BASE}/sessions", times: 1
  end

  def test_post_is_never_retried
    @config.max_retries = 2
    stub_request(:post, "#{BASE}/services/compute").to_return(status: 503, body: "{}")
    stub_request(:post, "#{BASE}/services/compute/u/restart").to_raise(Faraday::TimeoutError.new("read timeout"))

    assert_raises(OctaSpace::ServiceUnavailableError) { transport.post("/services/compute", body: {}) }
    assert_raises(OctaSpace::TimeoutError) { transport.post("/services/compute/u/restart") }
    assert_requested :post, "#{BASE}/services/compute", times: 1
    assert_requested :post, "#{BASE}/services/compute/u/restart", times: 1
  end

  def test_idempotent_post_is_retried
    @config.max_retries = 1
    stub_request(:post, "#{BASE}/services/u/stop")
      .to_return({status: 502, body: ""}, {status: 202, body: '{"uuid":"u"}'})

    assert_equal 202, transport.post("/services/u/stop", idempotent: true).status
  end

  # --- Network errors ---

  def test_connection_failed_maps_to_connection_error
    stub_request(:get, "#{BASE}/network").to_raise(Faraday::ConnectionFailed.new("Connection refused"))
    assert_raises(OctaSpace::ConnectionError) { transport.get("/network", auth: :none) }
  end

  def test_timeout_maps_to_timeout_error
    stub_request(:get, "#{BASE}/network").to_raise(Faraday::TimeoutError.new("read timeout"))
    assert_raises(OctaSpace::TimeoutError) { transport.get("/network", auth: :none) }
  end

  # --- Failover ---

  def test_get_fails_over_to_next_url
    @config.base_urls = ["https://bad.example", "https://good.example"]
    stub_request(:get, "https://bad.example/network").to_raise(Faraday::ConnectionFailed.new("refused"))
    stub_request(:get, "https://good.example/network").to_return(status: 200, body: "{}")

    assert transport.get("/network", auth: :none).success?
  end

  def test_get_raises_when_all_urls_fail
    @config.base_urls = ["https://bad1.example", "https://bad2.example"]
    stub_request(:get, "https://bad1.example/network").to_raise(Faraday::ConnectionFailed.new("refused"))
    stub_request(:get, "https://bad2.example/network").to_raise(Faraday::ConnectionFailed.new("refused"))

    assert_raises(OctaSpace::ConnectionError) { transport.get("/network", auth: :none) }
  end

  def test_post_is_not_sent_to_a_second_url
    @config.base_urls = ["https://bad.example", "https://good.example"]
    stub_request(:post, "https://bad.example/services/compute").to_raise(Faraday::TimeoutError.new("read timeout"))
    good = stub_request(:post, "https://good.example/services/compute").to_return(status: 201, body: "{}")

    assert_raises(OctaSpace::TimeoutError) { transport.post("/services/compute", body: {}) }
    assert_not_requested good
  end

  def test_http_error_does_not_fail_over
    @config.base_urls = ["https://a.example", "https://b.example"]
    stub_request(:get, "https://a.example/sessions").to_return(status: 404, body: "{}")
    other = stub_request(:get, "https://b.example/sessions").to_return(status: 200, body: "[]")

    assert_raises(OctaSpace::NotFoundError) { transport.get("/sessions") }
    assert_not_requested other
  end

  # --- Hooks and logging ---

  def test_on_request_hook_gets_context_without_headers
    seen = []
    @config.on_request = ->(ctx) { seen << ctx }
    stub_request(:get, "#{BASE}/network").to_return(status: 200, body: "{}")
    transport.get("/network", auth: :none)

    assert_equal :get, seen.first[:method]
    assert_equal "/network", seen.first[:path]
    assert_equal "#{BASE}/network", seen.first[:url]
    assert_equal 0, seen.first[:attempt]
    refute seen.first.key?(:headers)
  end

  def test_on_response_hook_gets_response
    seen = nil
    @config.on_response = ->(resp) { seen = resp }
    stub_request(:get, "#{BASE}/network").to_return(status: 200, body: "{}")
    transport.get("/network", auth: :none)

    assert_equal 200, seen.status
  end

  def test_logger_writes_one_line_without_the_key
    io = StringIO.new
    @config.logger = Logger.new(io)
    stub_request(:get, "#{BASE}/accounts/balance").to_return(status: 200, body: "{}")
    transport.get("/accounts/balance")

    assert_match(%r{\[OctaSpace\] GET #{Regexp.escape(BASE)}/accounts/balance -> 200 \(\d+ ms\)}o, io.string)
    refute_includes io.string, KEY
  end

  def test_requires_a_base_url
    @config.base_url = " "
    assert_raises(OctaSpace::ConfigurationError) { transport }
  end
end

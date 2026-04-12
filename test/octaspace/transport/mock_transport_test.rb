# frozen_string_literal: true

require "test_helper"

class OctaSpace::MockTransportTest < Minitest::Test
  def setup
    @config = OctaSpace::Configuration.new
    @config.api_key = "test_key"
    @transport = OctaSpace::Transport::MockTransport.new(@config, scenario: "slow", delay_seconds: 0)
  end

  def test_returns_mock_body_for_slow_scenario
    response = @transport.get("/nodes")

    assert_equal 200, response.status
    assert_equal "slow", response.data["scenario"]
    assert_equal "Mocked 200", response.data["error"]
  end

  def test_raises_typed_http_errors
    transport = OctaSpace::Transport::MockTransport.new(@config, scenario: "429", delay_seconds: 0)
    error = assert_raises(OctaSpace::RateLimitError) { transport.get("/nodes") }

    assert_equal 429, error.status
    assert_equal 60, error.retry_after
  end

  def test_raises_timeout_error_for_timeout_scenario
    transport = OctaSpace::Transport::MockTransport.new(@config, scenario: "timeout", delay_seconds: 0)

    error = assert_raises(OctaSpace::TimeoutError) { transport.get("/nodes") }
    assert_match(/Mocked timeout/, error.message)
  end

  def test_exposes_mock_transport_stats
    assert_equal :mock, @transport.transport_stats[:mode]
    assert_equal "slow", @transport.transport_stats[:scenario]
  end
end

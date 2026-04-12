# frozen_string_literal: true

require "test_helper"
require "octaspace/playground/smoke_runner"

class OctaSpace::Playground::SmokeRunnerTest < Minitest::Test
  def setup
    super
    @client = test_client
  end

  def test_run_returns_passed_summary_for_read_only_suites
    stub_get("/network", fixture_path: "network/index.json")
    stub_get("/accounts", fixture_path: "accounts/show.json")
    stub_get("/accounts/balance", fixture_path: "accounts/balance.json")
    stub_get("/apps", fixture_path: "apps/index.json")
    stub_get("/nodes", fixture_path: "nodes/index.json")
    stub_get("/services/mr", fixture_path: "services/mr/index.json")
    stub_get("/services/render", fixture_path: "services/mr/index.json")
    stub_get("/services/vpn", fixture_path: "services/vpn/index.json")
    stub_get("/sessions", fixture_path: "sessions/index.json")
    stub_request(:get, "#{StubHelpers::BASE_URL}/sessions")
      .with(query: {"recent" => "true"})
      .to_return(status: 200, body: fixture("sessions/index.json"), headers: json_headers)

    result = OctaSpace::Playground::SmokeRunner.new(client: @client).run

    assert_equal "sdk_smoke", result[:kind]
    assert_equal "passed", result[:status]
    assert_equal 10, result.dig(:summary, :total)
    assert_equal 10, result.dig(:summary, :passed)
    assert_equal 0, result.dig(:summary, :failed)
    assert_equal "network.info", result[:suites].first[:id]
    assert_equal "passed", result[:suites].first[:status]
  end
end

# frozen_string_literal: true

require "test_helper"
require_relative "dummy/config/environment"

class DummyDiagnosticsTest < Minitest::Test
  include FixtureHelpers

  def setup
    super
    ActionController::Base.allow_forgery_protection = false
    @session = ActionDispatch::Integration::Session.new(Rails.application)
    @session.host! "127.0.0.1"
  end

  def test_diagnostics_run_renders_error_card_for_mock_scenario
    @session.patch("/playground/settings", params: {mock_scenario: "401", return_to: "/playground/diagnostics"})
    @session.post("/playground/diagnostics/run", params: {call: "network.info"})

    assert_equal 200, @session.response.status
    assert_includes @session.response.body, "401 Unauthorized"
    assert_includes @session.response.body, "OctaSpace::AuthenticationError"
  end

  def test_diagnostics_run_executes_vpn_create_mutation
    payload = OctaSpace::Playground::PayloadPresets.payload_for("services.vpn.create").merge(node_id: 77)
    stub_request(:post, "https://api.octa.space/services/vpn")
      .with(body: payload.to_json)
      .to_return(status: 201, body: '{"uuid":"vpn-new-123","status":"starting"}', headers: {"Content-Type" => "application/json"})

    @session.patch("/playground/settings", params: {api_key: "test_key", mock_scenario: "real", return_to: "/playground/diagnostics"})
    @session.post("/playground/diagnostics/run", params: {call: "services.vpn.create", payload_json: JSON.pretty_generate(payload)})

    assert_equal 200, @session.response.status
    assert_includes @session.response.body, "Success"
    assert_includes @session.response.body, "vpn-new-123"
  end

  def test_diagnostics_run_executes_session_stop_mutation
    payload = OctaSpace::Playground::PayloadPresets.payload_for("services.session.stop")
    stub_request(:post, "https://api.octa.space/services/sess-abc-123/stop")
      .with(body: {score: payload[:score]}.to_json)
      .to_return(status: 200, body: '{"status":"stopped"}', headers: {"Content-Type" => "application/json"})

    @session.patch("/playground/settings", params: {api_key: "test_key", mock_scenario: "real", return_to: "/playground/diagnostics"})
    @session.post("/playground/diagnostics/run", params: {call: "services.session.stop", payload_json: JSON.pretty_generate(payload)})

    assert_equal 200, @session.response.status
    assert_includes @session.response.body, "Success"
    assert_includes @session.response.body, "stopped"
  end

  def test_diagnostics_run_executes_recent_session_logs_call
    payload = OctaSpace::Playground::PayloadPresets.payload_for("services.session.logs")
    stub_request(:get, "https://api.octa.space/services/sess-abc-123/logs")
      .with(query: {"recent" => "true"})
      .to_return(status: 200, body: fixture("services/session/logs.json"), headers: {"Content-Type" => "application/json"})

    @session.patch("/playground/settings", params: {api_key: "test_key", mock_scenario: "real", return_to: "/playground/diagnostics"})
    @session.post("/playground/diagnostics/run", params: {call: "services.session.logs", payload_json: JSON.pretty_generate(payload)})

    assert_equal 200, @session.response.status
    assert_includes @session.response.body, "Success"
    assert_includes @session.response.body, "octa_client.services.session(uuid).logs"
    assert_includes @session.response.body, "services/sess-abc-123/logs?recent=true"
    assert_includes @session.response.body, "Container started"
  end

  def test_diagnostics_run_reports_invalid_payload_json
    @session.patch("/playground/settings", params: {api_key: "test_key", mock_scenario: "real", return_to: "/playground/diagnostics"})
    @session.post("/playground/diagnostics/run", params: {call: "services.vpn.create", payload_json: "{not json}"})

    assert_equal 200, @session.response.status
    assert_includes @session.response.body, "OctaSpace::ValidationError"
    assert_includes @session.response.body, "Invalid payload JSON"
  end

  def test_diagnostics_smoke_runs_read_only_sdk_smoke_and_renders_json
    stub_request(:get, "https://api.octa.space/network")
      .to_return(status: 200, body: fixture("network/index.json"), headers: {"Content-Type" => "application/json"})
    stub_request(:get, "https://api.octa.space/accounts")
      .to_return(status: 200, body: fixture("accounts/show.json"), headers: {"Content-Type" => "application/json"})
    stub_request(:get, "https://api.octa.space/accounts/balance")
      .to_return(status: 200, body: fixture("accounts/balance.json"), headers: {"Content-Type" => "application/json"})
    stub_request(:get, "https://api.octa.space/apps")
      .to_return(status: 200, body: fixture("apps/index.json"), headers: {"Content-Type" => "application/json"})
    stub_request(:get, "https://api.octa.space/nodes")
      .to_return(status: 200, body: fixture("nodes/index.json"), headers: {"Content-Type" => "application/json"})
    stub_request(:get, "https://api.octa.space/services/mr")
      .to_return(status: 200, body: fixture("services/mr/index.json"), headers: {"Content-Type" => "application/json"})
    stub_request(:get, "https://api.octa.space/services/render")
      .to_return(status: 200, body: fixture("services/render/index.json"), headers: {"Content-Type" => "application/json"})
    stub_request(:get, "https://api.octa.space/services/vpn")
      .to_return(status: 200, body: fixture("services/vpn/index.json"), headers: {"Content-Type" => "application/json"})
    stub_request(:get, "https://api.octa.space/sessions")
      .to_return(status: 200, body: fixture("sessions/index.json"), headers: {"Content-Type" => "application/json"})
    stub_request(:get, "https://api.octa.space/sessions")
      .with(query: {"recent" => "true"})
      .to_return(status: 200, body: fixture("sessions/recent.json"), headers: {"Content-Type" => "application/json"})

    @session.patch("/playground/settings", params: {api_key: "test_key", mock_scenario: "real", return_to: "/playground/diagnostics"})
    @session.post("/playground/diagnostics/smoke", params: {call: "network.info"})

    assert_equal 200, @session.response.status
    assert_includes @session.response.body, "SDK Smoke passed"
    assert_includes @session.response.body, "sdk_smoke"
    assert_includes @session.response.body, "octa_client.sessions.list(recent: true)"
  end

  def test_diagnostics_run_executes_idle_job_find
    payload = OctaSpace::Playground::PayloadPresets.payload_for("idle_jobs.find")
    stub_request(:get, "https://api.octa.space/idle_jobs/69/42")
      .to_return(status: 200, body: fixture("idle_jobs/show.json"), headers: {"Content-Type" => "application/json"})

    @session.patch("/playground/settings", params: {api_key: "test_key", mock_scenario: "real", return_to: "/playground/diagnostics"})
    @session.post("/playground/diagnostics/run", params: {call: "idle_jobs.find", payload_json: JSON.pretty_generate(payload)})

    assert_equal 200, @session.response.status
    assert_includes @session.response.body, "completed"
    assert_includes @session.response.body, "octa_client.idle_jobs.find"
  end

  def test_diagnostics_show_prefills_payload_from_query_string
    payload = OctaSpace::Playground::PayloadPresets.payload_for("services.mr.create").merge(
      app: "249b4cb3-3db1-4c06-98a4-772ba88cd81c",
      image: "ubuntu:24.04"
    )

    @session.get("/playground/diagnostics", params: {call: "services.mr.create", payload_json: JSON.pretty_generate(payload)})

    assert_equal 200, @session.response.status
    assert_includes @session.response.body, "services.mr.create"
    assert_includes @session.response.body, "249b4cb3-3db1-4c06-98a4-772ba88cd81c"
    assert_includes @session.response.body, "ubuntu:24.04"
  end

  def test_diagnostics_show_marks_selected_card_for_scroll_restoration
    @session.get("/playground/diagnostics", params: {call: "services.session.logs"})

    assert_equal 200, @session.response.status
    assert_includes @session.response.body, "data-diagnostics-list"
    assert_includes @session.response.body, "data-diagnostics-item"
    assert_includes @session.response.body, 'data-selected="true"'
    assert_includes @session.response.body, "octa_client.services.session(uuid).logs"
  end
end

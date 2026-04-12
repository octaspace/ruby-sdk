# frozen_string_literal: true

require "test_helper"
require_relative "dummy/config/environment"

class DummySessionsTest < Minitest::Test
  include FixtureHelpers

  def setup
    super
    ActionController::Base.allow_forgery_protection = false
    @session = ActionDispatch::Integration::Session.new(Rails.application)
    @session.host! "127.0.0.1"
  end

  def test_sessions_stop_posts_stop_request_and_renders_notice
    stub_request(:get, "https://api.octa.space/sessions")
      .to_return(status: 200, body: fixture("sessions/index.json"), headers: {"Content-Type" => "application/json"})
    stub_request(:get, "https://api.octa.space/sessions")
      .with(query: {"recent" => "true"})
      .to_return(status: 200, body: fixture("sessions/index.json"), headers: {"Content-Type" => "application/json"})
    stub_request(:post, "https://api.octa.space/services/sess-abc-123/stop")
      .to_return(status: 200, body: '{"status":"stopped"}', headers: {"Content-Type" => "application/json"})

    @session.patch("/playground/settings", params: {api_key: "test_key", mock_scenario: "real", return_to: "/playground/sessions"})
    @session.post("/playground/sessions/stop", params: {uuid: "sess-abc-123", tab: "current"})

    assert_equal 303, @session.response.status
    assert_equal "http://127.0.0.1/playground/sessions?tab=current", @session.response.location

    @session.follow_redirect!

    assert_equal 200, @session.response.status
    assert_includes @session.response.body, "Stop request submitted"
    assert_includes @session.response.body, "sess-abc-123"
  end

  def test_sessions_stop_without_uuid_redirects_with_error
    stub_request(:get, "https://api.octa.space/sessions")
      .to_return(status: 200, body: fixture("sessions/index.json"), headers: {"Content-Type" => "application/json"})
    stub_request(:get, "https://api.octa.space/sessions")
      .with(query: {"recent" => "true"})
      .to_return(status: 200, body: fixture("sessions/index.json"), headers: {"Content-Type" => "application/json"})

    @session.patch("/playground/settings", params: {api_key: "test_key", mock_scenario: "real", return_to: "/playground/sessions"})
    @session.post("/playground/sessions/stop", params: {uuid: "", tab: "current"})

    assert_equal 303, @session.response.status
    @session.follow_redirect!

    assert_equal 200, @session.response.status
    assert_includes @session.response.body, "Stop request failed"
    assert_includes @session.response.body, "Session UUID is required"
  end
end

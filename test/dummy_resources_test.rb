# frozen_string_literal: true

require "cgi"
require "test_helper"
require_relative "dummy/config/environment"

class DummyResourcesTest < Minitest::Test
  include FixtureHelpers

  def setup
    super
    ActionController::Base.allow_forgery_protection = false
    @session = ActionDispatch::Integration::Session.new(Rails.application)
    @session.host! "127.0.0.1"
    @session.patch("/playground/settings", params: {api_key: "test_key", mock_scenario: "real", return_to: "/playground/dashboard"})
  end

  def test_apps_page_renders_app_catalog
    stub_request(:get, "https://api.octa.space/apps")
      .to_return(status: 200, body: fixture("apps/index.json"), headers: {"Content-Type" => "application/json"})

    @session.get("/playground/apps")

    assert_equal 200, @session.response.status
    assert_includes @session.response.body, "Apps"
    assert_includes @session.response.body, "Stable Diffusion"
    assert_includes @session.response.body, "Use in MR Create"
    assert_includes @session.response.body, CGI.escape("249b4cb3-3db1-4c06-98a4-772ba88cd81c")
    assert_includes @session.response.body, CGI.escape("ubuntu:24.04")
    assert_includes @session.response.body, 'data-scroll-target="apps-raw-json"'
    assert_includes @session.response.body, 'id="apps-raw-json"'
  end

  def test_layout_brand_link_points_to_root
    stub_request(:get, "https://api.octa.space/apps")
      .to_return(status: 200, body: fixture("apps/index.json"), headers: {"Content-Type" => "application/json"})

    @session.get("/playground/apps")

    assert_equal 200, @session.response.status
    assert_includes @session.response.body, 'href="/"'
    assert_includes @session.response.body, "SDK Playground"
    assert_includes @session.response.body, 'id="page-loader"'
    assert_includes @session.response.body, "Loading…"
  end

  def test_idle_jobs_page_renders_status_and_logs
    stub_request(:get, "https://api.octa.space/idle_jobs/69/42")
      .to_return(status: 200, body: fixture("idle_jobs/show.json"), headers: {"Content-Type" => "application/json"})
    stub_request(:get, "https://api.octa.space/idle_jobs/69/42/logs")
      .to_return(status: 200, body: fixture("idle_jobs/logs.json"), headers: {"Content-Type" => "application/json"})

    @session.get("/playground/idle-jobs", params: {node_id: 69, job_id: 42})

    assert_equal 200, @session.response.status
    assert_includes @session.response.body, "Idle Jobs"
    assert_includes @session.response.body, "Training complete."
    assert_includes @session.response.body, "completed"
  end

  def test_services_page_renders_marketplace_summary
    stub_request(:get, "https://api.octa.space/services/mr")
      .to_return(status: 200, body: fixture("services/mr/index.json"), headers: {"Content-Type" => "application/json"})
    stub_request(:get, "https://api.octa.space/services/render")
      .to_return(status: 200, body: fixture("services/render/index.json"), headers: {"Content-Type" => "application/json"})
    stub_request(:get, "https://api.octa.space/services/vpn")
      .to_return(status: 200, body: fixture("services/vpn/index.json"), headers: {"Content-Type" => "application/json"})

    @session.get("/playground/services")

    assert_equal 200, @session.response.status
    assert_includes @session.response.body, "Machine Rental Marketplace"
    assert_includes @session.response.body, "Marketplace Summary"
    assert_includes @session.response.body, "6977.8 Mbps"
  end
end

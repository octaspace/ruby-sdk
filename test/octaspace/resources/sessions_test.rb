# frozen_string_literal: true

require "test_helper"

class OctaSpace::SessionsResourceTest < Minitest::Test
  BASE = StubHelpers::BASE_URL
  UUID = "9b2f6c1e-3d4a-4f5b-8c7d-0e1f2a3b4c5d"

  def setup
    super
    @sleeps = []
    @client = test_client
    @sessions = OctaSpace::Resources::Sessions.new(@client.instance_variable_get(:@transport), sleeper: ->(s) { @sleeps << s })
  end

  def info_url = "#{BASE}/services/#{UUID}/info"

  # --- list / get ---

  def test_list_builds_sessions_by_service
    body = [JSON.parse(fixture("next/session_compute_ready.json")),
      {"service" => "render", "uuid" => "r", "status" => "ready", "duration" => 1},
      {"service" => "vpn", "uuid" => "v", "status" => "ready", "duration" => 1, "config" => "x"}]
    stub_request(:get, "#{BASE}/sessions").to_return(status: 200, body: body.to_json)

    compute, render, vpn = @client.sessions.list
    assert_instance_of OctaSpace::Types::ComputeSession, compute
    assert_instance_of OctaSpace::Types::RenderSession, render
    assert_instance_of OctaSpace::Types::Session, vpn
    assert vpn.ready?
    assert_equal "x", vpn[:config]
  end

  def test_list_requires_api_key
    assert_raises(OctaSpace::AuthenticationError) { OctaSpace::Client.new.sessions.list }
  end

  def test_get_parses_a_ready_compute_session
    stub_request(:get, info_url).to_return(status: 200, body: fixture("next/session_compute_ssh_proxy.json"))
    s = @client.sessions.get(UUID)

    assert s.compute?
    assert s.ready?
    assert_equal "M95S-WZG8-7", s.node_number
    assert_equal 22, s.charge_amount
    assert_equal Time.at(1_793_639_533.878), s.started_time
    assert_nil s.ssh.direct
    assert_equal "proxy.example.com", s.ssh.endpoint.host
    assert_equal 30232, s.ssh.endpoint.port
    assert_equal "root", s.ssh.proxy.user
    assert_equal 10, s.node_hw.disk
    assert_equal "NVIDIA GeForce RTX 3090", s.node_hw.gpus.first.model
    assert_equal({}, s.envs)
  end

  def test_starting_session_has_nil_fields
    stub_request(:get, info_url).to_return(status: 200, body: fixture("next/session_compute_starting.json"))
    s = @client.sessions.get(UUID)

    assert s.starting?
    refute s.ready?
  end

  def test_net_speed_in_node_hw
    stub_request(:get, info_url).to_return(status: 200, body: fixture("next/session_compute_net_mbps.json"))
    hw = @client.sessions.get(UUID).node_hw

    assert_kind_of Integer, hw.net_down_mbps
    assert_kind_of Integer, hw.net_up_mbps
  end

  def test_inspect_redacts_access_urls
    data = JSON.parse(fixture("next/session_compute_ssh_proxy.json"))
    data["fm"] = "https://fm.example/secret"
    data["ssh"]["web"] = "https://user:pass@term.example"
    stub_request(:get, info_url).to_return(status: 200, body: data.to_json)
    s = @client.sessions.get(UUID)

    refute_includes s.inspect, "fm.example"
    refute_includes s.ssh.inspect, "user:pass"
    assert_includes s.ssh.inspect, "[REDACTED]"
    assert_equal "https://user:pass@term.example", s.ssh.web
  end

  def test_get_404_and_400
    stub_request(:get, info_url).to_return(status: 404, body: '{"message":"Session not found"}')
    stub_request(:get, "#{BASE}/services/not-a-uuid/info").to_return(status: 400, body: '{"message":"Invalid session uuid"}')

    assert_raises(OctaSpace::NotFoundError) { @client.sessions.get(UUID) }
    assert_raises(OctaSpace::ValidationError) { @client.sessions.get("not-a-uuid") }
  end

  def test_uuid_is_path_encoded
    stub_request(:get, "#{BASE}/services/..%2Fx/info").to_return(status: 400, body: "{}")
    assert_raises(OctaSpace::ValidationError) { @client.sessions.get("../x") }
  end

  # --- logs ---

  def test_logs
    stub_request(:get, "#{BASE}/services/#{UUID}/logs").to_return(status: 200, body: fixture("next/session_logs.json"))
    logs = @client.sessions.logs(UUID)

    assert_kind_of OctaSpace::Types::LogEntry, logs.system.first
    assert_includes logs.system.first.msg, "Pulling"
    assert_kind_of Time, logs.system.first.time
    refute logs.container_truncated?
  end

  def test_logs_tail_and_null_container
    stub_request(:get, "#{BASE}/services/#{UUID}/logs").with(query: {"tail" => "5"})
      .to_return(status: 200, body: '{"system":[],"container":null,"container_truncated":false}')
    logs = @client.sessions.logs(UUID, tail: 5)

    assert_nil logs.container
    assert_equal [], logs.system
  end

  # --- stop ---

  def test_stop_returns_uuid_and_sends_no_body
    stub_request(:post, "#{BASE}/services/#{UUID}/stop").with { |r| r.body.to_s.empty? }
      .to_return(status: 202, body: %({"uuid":"#{UUID}"}))

    assert_equal UUID, @client.sessions.stop(UUID)
  end

  def test_stop_is_retried_on_transient_errors
    client = test_client(max_retries: 1, retry_interval: 0)
    stub_request(:post, "#{BASE}/services/#{UUID}/stop")
      .to_return({status: 503, body: "{}"}, {status: 202, body: ""})

    assert_equal UUID, client.sessions.stop(UUID)
  end

  # --- wait_ready / wait_stopped ---

  def test_wait_ready_polls_and_yields_progress
    stub_request(:get, info_url).to_return(
      {status: 200, body: fixture("next/session_compute_starting.json")},
      {status: 200, body: fixture("next/session_compute_ready.json")}
    )
    seen = []
    session = @sessions.wait_ready(UUID, interval: 2) { |s| seen << s.status }

    assert session.ready?
    assert_equal %w[starting ready], seen
    assert_equal [2], @sleeps
  end

  def test_wait_ready_raises_when_session_stops
    stub_request(:get, info_url).to_return(
      {status: 200, body: fixture("next/session_compute_starting.json")},
      {status: 404, body: '{"message":"Session not found"}'}
    )

    error = assert_raises(OctaSpace::SessionStoppedError) { @sessions.wait_ready(UUID) }
    assert_kind_of OctaSpace::NotFoundError, error
    assert_includes error.message, "stopped before it became ready"
  end

  def test_wait_ready_times_out
    stub_request(:get, info_url).to_return(status: 200, body: fixture("next/session_compute_starting.json"))

    assert_raises(OctaSpace::WaitTimeoutError) { @sessions.wait_ready(UUID, timeout: 1, interval: 5) }
  end

  def test_wait_stopped
    stub_request(:get, info_url).to_return(
      {status: 200, body: fixture("next/session_compute_ready.json")},
      {status: 404, body: '{"message":"Session not found"}'}
    )

    assert_equal true, @sessions.wait_stopped(UUID, interval: 1)
    assert_equal [1], @sleeps
  end
end

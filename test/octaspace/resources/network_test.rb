# frozen_string_literal: true

require "test_helper"

class OctaSpace::NetworkResourceTest < Minitest::Test
  def test_info_without_key
    stub_get("/network", fixture_path: "network.json")
    info = OctaSpace::Client.new.network.info

    assert_equal 3, info.nodes.online
    assert_equal 76, info.power.cpu_cores
    assert_in_delta 142.4, info.power.tflops
    assert_equal 6_588_996, info.render.frames_total
    assert_equal [], info.render.frames_by_week
    assert_equal 87, info.sessions.total
    assert_equal 0, info.vpn.nodes
    assert_equal Time.at(1_793_566_134), info.time
    assert_requested(:get, "#{StubHelpers::BASE_URL}/network") { |req| !req.headers.key?("Authorization") }
  end

  def test_info_never_sends_key
    stub_get("/network", fixture_path: "network.json")
    test_client.network.info
    assert_requested(:get, "#{StubHelpers::BASE_URL}/network") { |req| !req.headers.key?("Authorization") }
  end

  def test_unavailable
    stub_request(:get, "#{StubHelpers::BASE_URL}/network").to_return(status: 503, body: '{"message":"Network information is unavailable"}')
    assert_raises(OctaSpace::ServiceUnavailableError) { OctaSpace::Client.new.network.info }
  end

  def test_info_gpus_rented_and_null_strings
    stub_request(:get, "#{StubHelpers::BASE_URL}/network")
      .to_return(status: 200, body: '{"at":1,"power":{"gpus":7,"gpus_rented":"null"},"vpn":{"nodes":1,"countries":"null"}}')
    info = OctaSpace::Client.new.network.info

    assert_nil info.power.gpus_rented
    assert_nil info.vpn.countries
  end

  def test_history_params_and_points
    stub_request(:get, "#{StubHelpers::BASE_URL}/network/history")
      .with(query: {"start" => "1795000000", "end" => "1795086400", "step" => "3600"})
      .to_return(status: 200, body: fixture("network_history.json"))
    history = test_client.network.history(from: Time.at(1_795_000_000), to: 1_795_086_400, step: 3600)

    assert_instance_of OctaSpace::Types::NetworkHistory, history
    points = history.points
    assert_equal history.timestamps.size, points.size
    first = points.first
    assert_equal history.timestamps.first, first.ts
    assert_equal Time.at(first.ts), first.time
    assert_in_delta 6.92, first.gpus
    assert_equal history.users.first, first.users
    assert_requested(:get, %r{/network/history}) { |req| !req.headers.key?("Authorization") }
  end

  def test_history_defaults_and_null_strings
    stub_request(:get, "#{StubHelpers::BASE_URL}/network/history")
      .to_return(status: 200, body: '{"timestamps":[1,2],"nodes_online":[1.5,"null"],"sessions_24h":[null]}')
    points = OctaSpace::Client.new.network.history.points

    assert_in_delta 1.5, points[0].nodes_online
    assert_nil points[1].nodes_online
    assert_nil points[1].sessions_24h
    assert_nil points[0].vpn_nodes
  end

  def test_history_invalid_range
    stub_request(:get, "#{StubHelpers::BASE_URL}/network/history").with(query: {"step" => "60"})
      .to_return(status: 400, body: '{"message":"step must be at least 300 seconds"}')
    assert_raises(OctaSpace::ValidationError) { OctaSpace::Client.new.network.history(step: 60) }
  end
end

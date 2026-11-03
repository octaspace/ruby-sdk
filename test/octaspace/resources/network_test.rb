# frozen_string_literal: true

require "test_helper"

class OctaSpace::NetworkResourceTest < Minitest::Test
  def test_info_without_key
    stub_get("/network", fixture_path: "next/network.json")
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
    stub_get("/network", fixture_path: "next/network.json")
    test_client.network.info
    assert_requested(:get, "#{StubHelpers::BASE_URL}/network") { |req| !req.headers.key?("Authorization") }
  end

  def test_unavailable
    stub_request(:get, "#{StubHelpers::BASE_URL}/network").to_return(status: 503, body: '{"message":"Network information is unavailable"}')
    assert_raises(OctaSpace::ServiceUnavailableError) { OctaSpace::Client.new.network.info }
  end
end

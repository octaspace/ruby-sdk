# frozen_string_literal: true

require "test_helper"

class OctaSpace::HostingResourceTest < Minitest::Test
  BASE = StubHelpers::BASE_URL

  def setup
    super
    @client = test_client
  end

  def test_nodes
    stub_get("/hosting/nodes", fixture_path: "hosting_nodes.json")
    node = @client.hosting.nodes.find { |n| n.number == "7KQ4-M2XD-4" }

    assert node.idle?
    assert node.verified?
    refute node.maintenance?
    assert node.offered?(:compute)
    assert_nil node.services["compute"].reason
    assert_equal 100, node.prices.base
    assert_equal 0, node.prices.min_rent_minutes
    assert_equal 132_114_866_176, node.system.memory.size
    assert_equal "NVIDIA GeForce RTX 3090", node.system.gpus.first.model
    assert_equal "P8", node.system.gpus.first.pstate
    assert_equal "Frankfurt", node.location.city
    assert_equal Time.utc(2026, 11, 1, 18, 43, 45), node.online_time
    assert_nil node.activity
  end

  def test_nodes_repair_null_strings_in_gpus
    stub_request(:get, "#{BASE}/hosting/nodes").to_return(status: 200,
      body: '[{"number":"A","system":{"gpus":[{"fan_speed":"null","mem_free_mb":"","power_draw_watt":"12.5"}]}}]')
    gpu = @client.hosting.nodes.first.system.gpus.first

    assert_nil gpu.fan_speed
    assert_nil gpu.mem_free_mb
    assert_in_delta 12.5, gpu.power_draw_watt
  end

  def test_set_prices_sends_only_given_fields
    stub_request(:patch, "#{BASE}/hosting/nodes/7KQ4-M2XD-4/prices")
      .with(body: '{"base":250000,"min_rent_minutes":15}')
      .to_return(status: 204, body: "")

    assert_nil @client.hosting.set_prices("7KQ4-M2XD-4", base: 250_000, min_rent_minutes: 15, traffic: nil)
  end

  def test_set_prices_validates_locally
    assert_raises(ArgumentError) { @client.hosting.set_prices("A") }
    assert_raises(ArgumentError) { @client.hosting.set_prices("A", base: "100") }
    assert_raises(ArgumentError) { @client.hosting.set_prices("A", base: 0.25) }
    assert_raises(ArgumentError) { @client.hosting.set_prices("A", gpu_hour: 1) }
  end

  def test_set_prices_api_errors
    stub_request(:patch, "#{BASE}/hosting/nodes/ZZZZ-ZZZZ-Z/prices").to_return(status: 400, body: '{"message":"Invalid node number"}')
    stub_request(:patch, "#{BASE}/hosting/nodes/0000-0000-0/prices").to_return(status: 404, body: '{"message":"Node not found"}')

    assert_raises(OctaSpace::ValidationError) { @client.hosting.set_prices("ZZZZ-ZZZZ-Z", base: 100) }
    assert_raises(OctaSpace::NotFoundError) { @client.hosting.set_prices("0000-0000-0", base: 100) }
  end

  def test_get_one_node
    node = JSON.parse(fixture("hosting_nodes.json")).first
    node["services"] = {"vpn" => {"offered" => true, "protocols" => {
      "wg" => {"offered" => true, "reason" => nil},
      "reality" => {"offered" => false, "reason" => "vpn_probe_failed", "details" => "timeout"}
    }}}
    node["location"]["country"] = "null"
    stub_request(:get, "#{BASE}/hosting/nodes/7KQ4-M2XD-4").to_return(status: 200, body: node.to_json)
    result = @client.hosting.get("7KQ4-M2XD-4")

    assert_instance_of OctaSpace::Types::HostingNode, result
    assert_nil result.location.country
    vpn = result.services["vpn"]
    assert vpn.protocols["wg"].offered?
    refute vpn.protocols["reality"].offered?
    assert_equal "vpn_probe_failed", vpn.protocols["reality"].reason
    assert_equal "timeout", vpn.protocols["reality"].details
    assert_equal({}, result.services["vpn"].protocols["wg"].protocols)
  end

  def test_get_errors_and_auth
    stub_request(:get, "#{BASE}/hosting/nodes/0000-0000-0").to_return(status: 404, body: '{"message":"Node not found"}')

    assert_raises(OctaSpace::NotFoundError) { @client.hosting.get("0000-0000-0") }
    assert_raises(OctaSpace::AuthenticationError) { OctaSpace::Client.new.hosting.get("A") }
  end

  def test_maintenance_on_and_off
    url = "#{BASE}/hosting/nodes/7KQ4-M2XD-4/maintenance"
    stub_request(:put, url).to_return(status: 204, body: "")
    stub_request(:delete, url).to_return(status: 204, body: "")

    assert_nil @client.hosting.start_maintenance("7KQ4-M2XD-4")
    assert_nil @client.hosting.end_maintenance("7KQ4-M2XD-4")
    assert_requested(:put, url, headers: {"Authorization" => "Bearer test_key_123"}) { |req| req.body.to_s.empty? }
    assert_requested :delete, url
  end

  def test_maintenance_needs_key_and_escapes_number
    assert_raises(OctaSpace::AuthenticationError) { OctaSpace::Client.new.hosting.start_maintenance("A") }
    stub_request(:put, "#{BASE}/hosting/nodes/..%2Fx/maintenance").to_return(status: 400, body: '{"message":"Invalid node number"}')
    assert_raises(OctaSpace::ValidationError) { @client.hosting.start_maintenance("../x") }
  end

  def test_maintenance_is_retried
    client = test_client(max_retries: 1, retry_interval: 0)
    url = "#{BASE}/hosting/nodes/A/maintenance"
    stub_request(:delete, url).to_return({status: 503, body: ""}, {status: 204, body: ""})

    assert_nil client.hosting.end_maintenance("A")
    assert_requested :delete, url, times: 2
  end
end

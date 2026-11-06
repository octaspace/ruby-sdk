# frozen_string_literal: true

require "test_helper"

class OctaSpace::HostingResourceTest < Minitest::Test
  BASE = StubHelpers::BASE_URL

  def setup
    super
    @client = test_client
  end

  def test_nodes
    stub_get("/hosting/nodes", fixture_path: "next/hosting_nodes.json")
    node = @client.hosting.nodes.find { |n| n.number == "M95S-WZG8-7" }

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
    assert_equal "Mukachevo", node.location.city
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
    stub_request(:patch, "#{BASE}/hosting/nodes/M95S-WZG8-7/prices")
      .with(body: '{"base":250000,"min_rent_minutes":15}')
      .to_return(status: 204, body: "")

    assert_nil @client.hosting.set_prices("M95S-WZG8-7", base: 250_000, min_rent_minutes: 15, traffic: nil)
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
end

# frozen_string_literal: true

require "test_helper"

class OctaSpace::StatsResourceTest < Minitest::Test
  BASE = StubHelpers::BASE_URL

  def setup
    super
    @client = OctaSpace::Client.new
  end

  def test_gpu_current
    stub_request(:get, "#{BASE}/stats/gpu/current").with(query: {"verified" => "yes"})
      .to_return(status: 200, body: fixture("stats_gpu_current.json"))
    market = @client.stats.gpu_current(verified: :yes)

    gpu = market.gpus.first
    assert_equal "NVIDIA GeForce RTX 3090", gpu.model
    assert_equal 100_000, gpu.rented_price.p50
    assert_kind_of Time, market.time
  end

  def test_gpu_current_null_strings
    stub_request(:get, "#{BASE}/stats/gpu/current")
      .to_return(status: 200, body: '{"at":1,"gpus":[{"model":"X","tflops":"null","available_price":{"p10":"null"}}]}')
    gpu = @client.stats.gpu_current.gpus.first

    assert_nil gpu.tflops
    assert_nil gpu.available_price.p10
  end

  def test_gpu_history_params_and_points
    from = Time.at(1_793_000_000)
    stub_request(:get, "#{BASE}/stats/gpu/history")
      .with(query: {"gpu_name" => "Arc B580,NVIDIA GeForce RTX 3090", "start" => "1793000000", "end" => "1793086400", "step" => "3600"})
      .to_return(status: 200, body: fixture("stats_gpu_history.json"))

    history = @client.stats.gpu_history(gpu_name: ["Arc B580", "NVIDIA GeForce RTX 3090"], from: from, to: 1_793_086_400, step: 3600)
    arc = history.fetch("Arc B580")
    assert_instance_of OctaSpace::Types::GpuHistory, arc
    assert_nil arc.tflops

    points = arc.points
    assert_equal arc.timestamps.size, points.size
    assert_equal arc.supply_demand.total.first, points.first.total
    assert_equal arc.rented_price.p50, points.map { |p| p.rented_price.p50 }
    assert_equal Time.at(arc.timestamps.first), points.first.time
  end

  def test_gpu_history_validation_error
    stub_request(:get, "#{BASE}/stats/gpu/history").with(query: {"step" => "10"})
      .to_return(status: 400, body: '{"message":"step must be at least 300 seconds"}')

    error = assert_raises(OctaSpace::ValidationError) { @client.stats.gpu_history(step: 10) }
    assert_equal "step must be at least 300 seconds", error.message
  end

  def test_gpu_locations
    stub_get("/stats/gpu/locations", fixture_path: "stats_gpu_locations.json")
    loc = @client.stats.gpu_locations.first

    assert_equal "Mukachevo", loc.city
    assert_equal "Arc B580", loc.model
    assert_equal 2, loc.gpus
  end
end

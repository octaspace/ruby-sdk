# frozen_string_literal: true

require "test_helper"

class OctaSpace::RenderResourceTest < Minitest::Test
  BASE = StubHelpers::BASE_URL

  def setup
    super
    @client = test_client
  end

  def test_list_returns_render_machines
    stub_get("/services/render", fixture_path: "next/services_render.json")
    machines = @client.render.list

    assert(machines.all?(OctaSpace::Types::RenderMachine))
    m = machines.first
    assert_equal "7R2S-S05E-S", m.node_number
    assert_equal 100_000, m.base_price
    assert_equal 5101, m.blender_score
    refute_respond_to m, :storage_price
  end

  def test_start_sends_only_node_number
    stub_request(:post, "#{BASE}/services/render")
      .with(body: '{"node_number":"7R2S-S05E-S"}')
      .to_return(status: 201, body: '{"uuid":"r-1"}')

    assert_equal "r-1", @client.render.start(node_number: "7R2S-S05E-S")
  end

  def test_start_503_is_service_unavailable
    stub_request(:post, "#{BASE}/services/render").to_return(status: 503, body: '{"message":"Service is temporarily unavailable"}')

    error = assert_raises(OctaSpace::ServiceUnavailableError) { @client.render.start(node_number: "A") }
    assert_equal "Service is temporarily unavailable", error.message
  end

  def test_start_batch_reports_unavailable_per_item
    stub_request(:post, "#{BASE}/services/render")
      .with(body: '[{"id":0,"node_number":"7R2S-S05E-S"},{"id":1,"node_number":"ZZZZ-ZZZZ-Z"}]')
      .to_return(status: 200, body: '[{"id":0,"status":1,"reason":"Service is temporarily unavailable"},' \
                                     '{"id":1,"status":1,"reason":"Invalid node number"}]')

    results = @client.render.start_batch([{node_number: "7R2S-S05E-S"}, {node_number: "ZZZZ-ZZZZ-Z"}])
    assert(results.all?(&:failed?))
    assert_equal "Service is temporarily unavailable", results.first.reason
  end

  def test_start_batch_rejects_legacy_fields
    assert_raises(ArgumentError) { @client.render.start_batch([{node_number: "A", disk_size: 100}]) }
  end
end

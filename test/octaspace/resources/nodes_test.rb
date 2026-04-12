# frozen_string_literal: true

require "test_helper"

class OctaSpace::NodesResourceTest < Minitest::Test
  def setup
    super
    @client = test_client
  end

  def test_list_returns_array
    stub_get("/nodes", fixture_path: "nodes/index.json")
    response = @client.nodes.list
    assert response.success?
    assert_kind_of Array, response.data
    assert_equal 2, response.data.size
  end

  def test_find_returns_single_node
    stub_get("/nodes/1", fixture_path: "nodes/show.json")
    response = @client.nodes.find(1)
    assert response.success?
    assert_equal 1, response.data["id"]
    assert_equal "online", response.data["state"]
  end

  def test_find_raises_not_found
    stub_error(:get, "/nodes/99999", status: 404, message: "Node not found")
    assert_raises(OctaSpace::NotFoundError) { @client.nodes.find(99999) }
  end

  def test_reboot_returns_success
    stub_request(:get, "#{StubHelpers::BASE_URL}/nodes/1/reboot")
      .to_return(status: 200, body: "{}", headers: json_headers)
    response = @client.nodes.reboot(1)
    assert response.success?
  end

  def test_update_prices
    stub_request(:patch, "#{StubHelpers::BASE_URL}/nodes/1/prices")
      .to_return(status: 200, body: "{}", headers: json_headers)
    response = @client.nodes.update_prices(1, gpu_hour: 0.5, cpu_hour: 0.1)
    assert response.success?
  end

  def test_list_passes_params
    stub_request(:get, "#{StubHelpers::BASE_URL}/nodes")
      .with(query: {"state" => "online"})
      .to_return(status: 200, body: "[]", headers: json_headers)
    response = @client.nodes.list(state: "online")
    assert response.success?
  end
end

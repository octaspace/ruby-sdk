# frozen_string_literal: true

require "test_helper"

class OctaSpace::NetworkResourceTest < Minitest::Test
  def setup
    super
    @client = test_client
  end

  def test_info_returns_response
    stub_get("/network", fixture_path: "network/index.json")
    response = @client.network.info
    assert response.success?
    assert response.data.key?("blockchain")
    assert response.data.key?("market_price")
    assert response.data.key?("nodes")
  end

  def test_info_raises_server_error_on_500
    stub_error(:get, "/network", status: 500, message: "Internal Server Error")
    assert_raises(OctaSpace::ServerError) { @client.network.info }
  end
end

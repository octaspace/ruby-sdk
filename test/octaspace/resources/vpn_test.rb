# frozen_string_literal: true

require "test_helper"

class OctaSpace::VpnResourceTest < Minitest::Test
  BASE = StubHelpers::BASE_URL
  UUID = "96e33710-ec12-11ed-8588-fa163e49e8aa"

  def setup
    super
    @client = test_client
  end

  def test_list
    stub_get("/services/vpn", fixture_path: "services_vpn.json")
    node = @client.vpn.list.first

    assert_instance_of OctaSpace::Types::VpnMachine, node
    assert_equal "7KQ4-M2XD-4", node.node_number
    assert_equal 100, node.traffic_price
    assert node.supports?(:wg)
    assert node.supports?("http_proxy")
    refute node.supports?(:v2ray)
    refute node.residential?
    assert_equal "DE", node.country_iso
    assert_requested(:get, "#{BASE}/services/vpn", headers: {"Authorization" => "Bearer test_key_123"})
  end

  def test_list_without_key_and_null_strings
    stub_request(:get, "#{BASE}/services/vpn").to_return(status: 200, body: '[{"node_number":"A","country":"null","protocols":["wg"]}]')
    node = OctaSpace::Client.new.vpn.list.first

    assert_nil node.country
    assert_requested(:get, "#{BASE}/services/vpn") { |req| !req.headers.key?("Authorization") }
  end

  def test_start_sends_node_and_subkind
    stub_request(:post, "#{BASE}/services/vpn")
      .with(body: '{"node_number":"7KQ4-M2XD-4","subkind":"http_proxy"}')
      .to_return(status: 201, body: %({"uuid":"#{UUID}"}))

    assert_equal UUID, @client.vpn.start(node_number: "7KQ4-M2XD-4", subkind: :http_proxy)
  end

  def test_start_rejects_other_arguments_and_needs_key
    assert_raises(ArgumentError) { @client.vpn.start(node_number: "A", subkind: "wg", protocol: "trojan") }
    assert_raises(ArgumentError) { @client.vpn.start(node_number: "A") }
    assert_raises(OctaSpace::AuthenticationError) { OctaSpace::Client.new.vpn.start(node_number: "A", subkind: "wg") }
  end

  def test_start_refused_is_validation_error_and_not_retried
    client = test_client(max_retries: 2)
    stub_request(:post, "#{BASE}/services/vpn")
      .to_return(status: 400, body: %({"message":"Node's VPN did not pass the connection check"}))

    error = assert_raises(OctaSpace::ValidationError) { client.vpn.start(node_number: "A", subkind: "wg") }
    assert_equal "Node's VPN did not pass the connection check", error.message
    assert_requested :post, "#{BASE}/services/vpn", times: 1
  end
end

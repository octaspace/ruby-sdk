# frozen_string_literal: true

require "test_helper"

class OctaSpace::ClientTest < Minitest::Test
  def test_initializes_all_resources
    client = test_client
    assert_instance_of OctaSpace::Resources::Accounts,  client.accounts
    assert_instance_of OctaSpace::Resources::Nodes,     client.nodes
    assert_instance_of OctaSpace::Resources::Sessions,  client.sessions
    assert_instance_of OctaSpace::Resources::Apps,      client.apps
    assert_instance_of OctaSpace::Resources::Network,   client.network
    assert_instance_of OctaSpace::Resources::Services,  client.services
    assert_instance_of OctaSpace::Resources::IdleJobs,  client.idle_jobs
  end

  def test_uses_standard_transport_by_default
    client = test_client
    assert_instance_of OctaSpace::Transport::FaradayTransport,
      client.instance_variable_get(:@transport)
  end

  def test_raises_configuration_error_for_keep_alive_without_gems
    # Only run this test if net_http_persistent is NOT loaded
    skip "faraday-net_http_persistent is installed" if defined?(Faraday::Adapter::NetHttpPersistent)

    assert_raises(OctaSpace::ConfigurationError) do
      OctaSpace::Client.new(api_key: "key", keep_alive: true)
    end
  end

  def test_per_instance_overrides_global_config
    OctaSpace.configure { |c| c.read_timeout = 30 }
    client = OctaSpace::Client.new(api_key: "key", read_timeout: 60)
    config = client.instance_variable_get(:@config)
    assert_equal 60, config.read_timeout
  end

  def test_global_config_not_mutated_by_instance
    OctaSpace.configure { |c| c.read_timeout = 30 }
    OctaSpace::Client.new(api_key: "key", read_timeout: 60)
    assert_equal 30, OctaSpace.configuration.read_timeout
  end

  def test_transport_stats_returns_hash
    client = test_client
    stats = client.transport_stats
    assert_kind_of Hash, stats
    assert_equal :standard, stats[:mode]
  end
end

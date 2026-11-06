# frozen_string_literal: true

require "test_helper"

class OctaSpace::ComputeResourceTest < Minitest::Test
  BASE = StubHelpers::BASE_URL
  UUID = "5f3c2b1a-7d6e-4f8a-9b0c-1d2e3f4a5b6c"

  def setup
    super
    @client = test_client
  end

  # --- list ---

  def test_list_returns_machines_from_live_fixture
    stub_get("/services/compute", fixture_path: "services_compute.json")
    machines = @client.compute.list

    assert_equal 3, machines.size
    m = machines.find { |x| x.node_number == "7KQ4-M2XD-4" }
    assert_instance_of OctaSpace::Types::ComputeMachine, m
    assert_equal 100, m.base_price
    assert_equal 100, m.storage_price
    assert_equal 0, m.min_rent_minutes
    assert_equal 240, m.net_down_mbps
    assert_equal "nvme", m.disk_type
    assert_equal "NVIDIA GeForce RTX 3090", m.gpus.first.model
    assert_equal 24_576, m.gpus.first.mem_total_mb
    assert_in_delta 96.2, m.reliability.uptime, 0.1
    assert_equal 14, m.reliability[:s_normal]
  end

  def test_list_turns_null_strings_into_nil
    stub_get("/services/compute", fixture_path: "services_compute.json")
    arc = @client.compute.list.find { |x| x.gpus.any? { |g| g.model.to_s.include?("Arc") } }

    assert_nil arc.gpus.first.mem_clock
    assert_nil arc.gpus.first.power_limit
  end

  def test_list_coerces_string_gpu_integers
    stub_request(:get, "#{BASE}/services/compute").to_return(status: 200,
      body: '[{"node_number":"A","gpus":[{"power_limit":"390","mem_clock":"","core_clock":"n/a"}]}]')
    gpu = @client.compute.list.first.gpus.first

    assert_equal 390, gpu.power_limit
    assert_nil gpu.mem_clock
    assert_nil gpu.core_clock
  end

  def test_list_works_without_api_key
    stub_request(:get, "#{BASE}/services/compute").to_return(status: 200, body: "[]")
    assert_equal [], OctaSpace::Client.new.compute.list
    assert_requested(:get, "#{BASE}/services/compute") { |req| !req.headers.key?("Authorization") }
  end

  def test_list_sends_key_when_present
    stub_request(:get, "#{BASE}/services/compute").to_return(status: 200, body: "[]")
    @client.compute.list
    assert_requested :get, "#{BASE}/services/compute", headers: {"Authorization" => "Bearer test_key_123"}
  end

  def test_unknown_fields_are_kept
    stub_request(:get, "#{BASE}/services/compute").to_return(status: 200, body: '[{"node_number":"A","future":42}]')
    m = @client.compute.list.first

    assert_equal 42, m[:future]
    assert_equal({"node_number" => "A", "future" => 42}, m.to_h)
  end

  # --- start ---

  def test_start_sends_object_and_returns_uuid
    stub_request(:post, "#{BASE}/services/compute")
      .with(body: {node_number: "7KQ4-M2XD-4", image: "alpine:3.20", disk_size: 1, envs: {"A" => "1"},
                   http_ports: [8080], ssh: false}.to_json)
      .to_return(status: 201, body: %({"uuid":"#{UUID}"}))

    uuid = @client.compute.start(node_number: "7KQ4-M2XD-4", image: "alpine:3.20", disk_size: 1,
      envs: {"A" => "1"}, http_ports: [8080], ssh: false, fm: nil)
    assert_equal UUID, uuid
  end

  def test_start_requires_node_number_and_image
    error = assert_raises(ArgumentError) { @client.compute.start(image: "x") }
    assert_includes error.message, "node_number"
  end

  def test_start_rejects_unknown_parameters
    error = assert_raises(ArgumentError) { @client.compute.start(node_number: "A", image: "x", start_command: "sh") }
    assert_includes error.message, "start_command"
  end

  def test_start_maps_400_to_validation_error
    stub_request(:post, "#{BASE}/services/compute").to_return(status: 400, body: '{"message":"Insufficient balance"}')

    error = assert_raises(OctaSpace::ValidationError) { @client.compute.start(node_number: "A", image: "x") }
    assert_equal "Insufficient balance", error.message
  end

  def test_start_is_not_retried
    stub_request(:post, "#{BASE}/services/compute").to_return(status: 503, body: "{}")
    client = test_client(max_retries: 3)

    assert_raises(OctaSpace::ServiceUnavailableError) { client.compute.start(node_number: "A", image: "x") }
    assert_requested :post, "#{BASE}/services/compute", times: 1
  end

  # --- start_batch ---

  def test_start_batch_assigns_positions_and_parses_results
    stub_request(:post, "#{BASE}/services/compute")
      .with(body: [{id: "one", node_number: "A", image: "x"}, {id: 1, node_number: "B", image: "x"}].to_json)
      .to_return(status: 200, body: fixture("batch.json"))

    results = @client.compute.start_batch([{id: "one", node_number: "A", image: "x"}, {node_number: "B", image: "x"}])
    assert_equal 3, results.size
    assert results[0].started?
    assert_equal "8e1d4c7b-2a9f-4e3d-b6c5-0f1a2b3c4d5e", results[0].uuid
    assert results[1].failed?
    assert_equal "two", results[1].id
    assert_match(/node_number must be/, results[1].reason)
  end

  def test_start_batch_rejects_duplicate_ids
    error = assert_raises(ArgumentError) do
      @client.compute.start_batch([{id: 1, node_number: "A", image: "x"}, {node_number: "B", image: "x"}, {node_number: "C", image: "x"}])
    end
    assert_includes error.message, "duplicate batch id 1"
  end

  def test_start_batch_rejects_empty_and_unknown
    assert_raises(ArgumentError) { @client.compute.start_batch([]) }
    assert_raises(ArgumentError) { @client.compute.start_batch([{node_number: "A", image: "x", node_id: 1}]) }
  end

  # --- restart ---

  def test_restart_without_params_sends_no_body
    stub_request(:post, "#{BASE}/services/compute/#{UUID}/restart")
      .with { |req| req.body.to_s.empty? }
      .to_return(status: 202, body: %({"uuid":"#{UUID}"}))

    assert_equal UUID, @client.compute.restart(UUID)
  end

  def test_restart_with_params_sends_them
    stub_request(:post, "#{BASE}/services/compute/#{UUID}/restart")
      .with(body: {disk_size: 10, envs: {"K" => "V"}, entrypoint: "sh -c", args: "sleep 1"}.to_json)
      .to_return(status: 202, body: "")

    assert_equal UUID, @client.compute.restart(UUID, disk_size: 10, envs: {"K" => "V"}, entrypoint: "sh -c", args: "sleep 1")
  end

  def test_restart_rejects_image
    assert_raises(ArgumentError) { @client.compute.restart(UUID, image: "other") }
  end

  def test_restart_conflict_and_cooldown
    stub_request(:post, "#{BASE}/services/compute/#{UUID}/restart").to_return(
      {status: 409, body: '{"message":"Session is still starting or restarting"}'},
      {status: 429, body: '{"message":"Session was restarted too recently, retry in 288 seconds"}',
       headers: {"Retry-After" => "288"}}
    )

    assert_raises(OctaSpace::ConflictError) { @client.compute.restart(UUID) }
    error = assert_raises(OctaSpace::RateLimitError) { @client.compute.restart(UUID) }
    assert_equal 288, error.retry_after
  end
end

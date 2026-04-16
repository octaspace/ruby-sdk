# frozen_string_literal: true

require "test_helper"

class OctaSpace::ServicesResourceTest < Minitest::Test
  def setup
    super
    @client = test_client
  end

  # --- Services namespace ---

  def test_services_exposes_mr_vpn_render
    assert_instance_of OctaSpace::Resources::Services::MachineRental, @client.services.mr
    assert_instance_of OctaSpace::Resources::Services::Vpn, @client.services.vpn
    assert_instance_of OctaSpace::Resources::Services::Render, @client.services.render
  end

  def test_services_session_returns_proxy
    proxy = @client.services.session("sess-abc-123")
    assert_instance_of OctaSpace::Resources::Services::SessionProxy, proxy
  end

  # --- MachineRental ---

  def test_mr_list_returns_array
    stub_get("/services/mr", fixture_path: "services/mr/index.json")
    response = @client.services.mr.list
    assert response.success?
    assert_kind_of Array, response.data
    assert_equal 9010, response.data.first["node_id"]
    assert_equal "France", response.data.first["country"]
    assert_kind_of Hash, response.data.first["reliability"]
  end

  def test_mr_create_returns_success
    payload = OctaSpace::Playground::PayloadPresets.payload_for("services.mr.create").merge(
      organization_id: 77,
      project_id: 88
    )
    stub_request(:post, "#{StubHelpers::BASE_URL}/services/mr")
      .with(body: [
        {
          id: 0,
          node_id: payload[:node_id],
          disk_size: payload[:disk_size],
          image: payload[:image],
          app: payload[:app],
          envs: {},
          ports: [],
          http_ports: [],
          start_command: "",
          entrypoint: "",
          organization_id: 77,
          project_id: 88
        }
      ].to_json)
      .to_return(status: 201, body: '{"uuid":"new-sess","status":"starting"}', headers: json_headers)

    response = @client.services.mr.create(**payload)
    assert response.success?
    assert_equal "new-sess", response.data["uuid"]
  end

  def test_mr_create_raises_api_error_on_400_object_rejection
    payload = OctaSpace::Playground::PayloadPresets.payload_for("services.mr.create")
    stub_request(:post, "#{StubHelpers::BASE_URL}/services/mr")
      .to_return(status: 400, body: '{"message":"Node not found"}', headers: json_headers)

    assert_raises(OctaSpace::ApiError) { @client.services.mr.create(**payload) }
  end

  def test_mr_create_raises_provision_rejected_error_on_batch_rejection
    payload = OctaSpace::Playground::PayloadPresets.payload_for("services.mr.create")
    stub_request(:post, "#{StubHelpers::BASE_URL}/services/mr")
      .to_return(
        status: 200,
        body: '[{"id":0,"reason":"Node not found","status":1}]',
        headers: json_headers
      )

    error = assert_raises(OctaSpace::ProvisionRejectedError) { @client.services.mr.create(**payload) }
    assert_includes error.message, "Node not found"
    assert_equal 1, error.rejections.length
  end

  def test_mr_list_raises_not_found_on_404
    stub_error(:get, "/services/mr", status: 404, message: "Not Found")
    assert_raises(OctaSpace::NotFoundError) { @client.services.mr.list }
  end

  # --- VPN ---

  def test_vpn_list_returns_array
    stub_get("/services/vpn", fixture_path: "services/vpn/index.json")
    response = @client.services.vpn.list
    assert response.success?
    assert_kind_of Array, response.data
    assert_equal 9539, response.data.first["node_id"]
    refute response.data.first["residential"]
  end

  def test_vpn_create_returns_success
    payload = OctaSpace::Playground::PayloadPresets.payload_for("services.vpn.create")
    stub_post("/services/vpn", status: 201, body: '{"uuid":"new-vpn","status":"starting"}')
    response = @client.services.vpn.create(**payload)
    assert response.success?
  end

  # --- Render ---

  def test_render_list_returns_success
    stub_get("/services/render", status: 200, fixture_path: "services/render/index.json")
    response = @client.services.render.list
    assert response.success?
    assert_equal "NVIDIA RTX A6000", response.data.first["gpu"]
  end

  def test_render_create_returns_success
    payload = OctaSpace::Playground::PayloadPresets.payload_for("services.render.create")
    stub_post("/services/render", status: 201, body: '{"uuid":"new-render","status":"queued"}')
    response = @client.services.render.create(**payload)
    assert response.success?
  end

  # --- SessionProxy ---

  def test_session_proxy_info
    stub_get("/services/sess-abc-123/info", fixture_path: "services/session/info.json")
    response = @client.services.session("sess-abc-123").info
    assert response.success?
    assert_equal "sess-abc-123", response.data["uuid"]
    assert_equal "running", response.data["status"]
  end

  def test_session_proxy_logs
    stub_get("/services/sess-abc-123/logs", fixture_path: "services/session/logs.json")
    response = @client.services.session("sess-abc-123").logs
    assert response.success?
    assert_kind_of Hash, response.data
    assert_kind_of Array, response.data["system"]
  end

  def test_session_proxy_logs_with_recent_flag
    stub_request(:get, "#{StubHelpers::BASE_URL}/services/sess-abc-123/logs")
      .with(query: {"recent" => "true"})
      .to_return(status: 200, body: fixture("services/session/logs.json"), headers: json_headers)

    response = @client.services.session("sess-abc-123").logs(recent: true)
    assert response.success?
    assert_equal "", response.data["container"]
  end

  def test_session_proxy_stop
    payload = OctaSpace::Playground::PayloadPresets.payload_for("services.session.stop")
    stub_post("/services/sess-abc-123/stop", status: 200, body: '{"status":"stopped"}')
    response = @client.services.session(payload[:uuid]).stop(score: payload[:score])
    assert response.success?
  end

  def test_session_proxy_stop_without_params
    stub_post("/services/sess-abc-123/stop", status: 200, body: '{"status":"stopped"}')
    response = @client.services.session("sess-abc-123").stop
    assert response.success?
  end

  def test_session_proxy_raises_not_found
    stub_error(:get, "/services/bad-uuid/info", status: 404, message: "Session not found")
    assert_raises(OctaSpace::NotFoundError) { @client.services.session("bad-uuid").info }
  end
end

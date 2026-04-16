# frozen_string_literal: true

require "test_helper"
require "octaspace/playground/payload_presets"

class OctaSpace::Playground::PayloadPresetsTest < Minitest::Test
  def setup
    super
    OctaSpace::Playground::PayloadPresets.reset!
  end

  def test_mr_preset_matches_live_script_contract
    payload = OctaSpace::Playground::PayloadPresets.payload_for("services.mr.create")

    assert_equal 10, payload[:disk_size]
    assert_equal "ubuntu:24.04", payload[:image]
    assert_match(/\A[0-9a-f-]{36}\z/, payload[:app])
  end

  def test_payload_json_for_returns_pretty_json_object
    json = OctaSpace::Playground::PayloadPresets.payload_json_for("services.session.stop")

    assert_includes json, "\"uuid\""
    assert_equal({"uuid" => "sess-abc-123", "score" => 5}, JSON.parse(json))
  end

  def test_logs_preset_defaults_to_recent_finished_session_flow
    payload = OctaSpace::Playground::PayloadPresets.payload_for("services.session.logs")

    assert_equal "sess-abc-123", payload[:uuid]
    assert_equal true, payload[:recent]
  end
end

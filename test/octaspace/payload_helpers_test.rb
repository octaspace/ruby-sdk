# frozen_string_literal: true

require "test_helper"

class OctaSpace::PayloadHelpersTest < Minitest::Test
  def test_parse_port_list_accepts_arrays
    assert_equal [5000, 6000], OctaSpace::PayloadHelpers.parse_port_list([5000, 6000])
  end

  def test_parse_port_list_parses_json_strings
    assert_equal [8080, 8888], OctaSpace::PayloadHelpers.parse_port_list("[8080,8888]")
  end

  def test_parse_port_list_returns_empty_array_for_invalid_string
    assert_equal [], OctaSpace::PayloadHelpers.parse_port_list("not-json")
  end

  def test_parse_port_list_returns_empty_array_for_nil
    assert_equal [], OctaSpace::PayloadHelpers.parse_port_list(nil)
  end

  def test_normalize_marketplace_bandwidth_preserves_small_values
    assert_equal 250.0, OctaSpace::PayloadHelpers.normalize_marketplace_bandwidth(250)
  end

  def test_normalize_marketplace_bandwidth_converts_large_values
    assert_in_delta 6977.836424, OctaSpace::PayloadHelpers.normalize_marketplace_bandwidth(872_229_553), 0.000001
  end

  def test_normalize_marketplace_bandwidth_returns_nil_for_nil
    assert_nil OctaSpace::PayloadHelpers.normalize_marketplace_bandwidth(nil)
  end
end

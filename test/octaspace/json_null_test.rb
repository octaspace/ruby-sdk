# frozen_string_literal: true

require "test_helper"

class OctaSpace::JsonNullTest < Minitest::Test
  def test_null_strings_replaced_recursively_but_not_keys
    data = {"null" => "null", "a" => ["null", {"b" => "null", "c" => "x"}], "d" => 1}
    OctaSpace::JsonNull.null_strings!(data)

    assert_equal({"null" => nil, "a" => [nil, {"b" => nil, "c" => "x"}], "d" => 1}, data)
  end

  def test_number
    assert_equal 390, OctaSpace::JsonNull.number(" 390 ")
    assert_in_delta 1.5, OctaSpace::JsonNull.number("1.5")
    assert_nil OctaSpace::JsonNull.number("")
    assert_nil OctaSpace::JsonNull.number("null")
    assert_equal 7, OctaSpace::JsonNull.number(7)
    assert_nil OctaSpace::JsonNull.number(nil)
  end
end

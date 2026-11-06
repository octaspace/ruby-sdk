# frozen_string_literal: true

require "test_helper"

class OctaSpace::ModelTest < Minitest::Test
  class Inner < OctaSpace::Model
    attribute :name
  end

  class Outer < OctaSpace::Model
    attribute :id
    attribute :inner, model: Inner
    attribute :items, model: Inner, many: true
  end

  def setup
    super
    @outer = Outer.new("id" => 1, "inner" => {"name" => "a"}, "items" => [{"name" => "b"}, nil], "extra" => true)
  end

  def test_readers_and_nested_models
    assert_equal 1, @outer.id
    assert_equal "a", @outer.inner.name
    assert_equal ["b", nil], @outer.items.map { |i| i&.name }
    assert_same @outer.inner, @outer.inner
  end

  def test_missing_and_null_values
    empty = Outer.new({})
    assert_nil empty.id
    assert_nil empty.inner
    assert_equal [], Outer.new("items" => nil).items
    refute empty.key?(:id)
  end

  def test_unknown_fields_and_raw_hash
    assert_equal true, @outer[:extra]
    assert_equal true, @outer["extra"]
    assert_equal({"name" => "a"}, @outer.to_h["inner"])
  end

  def test_equality_and_inspect
    assert_equal Outer.new("id" => 1), Outer.new(id: 1)
    refute_equal Outer.new("id" => 1), Inner.new("id" => 1)
    assert_equal "#<OctaSpace::ModelTest::Outer id=1>", Outer.new("id" => 1, "inner" => {}).inspect
  end

  def test_pattern_matching
    case @outer
    in {id: Integer => id, extra: true}
      assert_equal 1, id
    end
  end

  def test_attributes_are_inherited
    sub = Class.new(Outer) { attribute :more }
    assert_equal %i[id inner items more], sub.attribute_names
    assert_equal %i[id inner items], Outer.attribute_names
  end
end

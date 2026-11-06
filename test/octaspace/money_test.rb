# frozen_string_literal: true

require "test_helper"

class OctaSpace::MoneyTest < Minitest::Test
  Money = OctaSpace::Money

  def test_format
    assert_equal "$0.000100", Money.format(100)
    assert_equal "$0.000000", Money.format(0)
    assert_equal "-$1.250000", Money.format(-1_250_000)
    assert_equal "$9007199254.740993", Money.format(9_007_199_254_740_993)
    assert_equal "$12", Money.format(12, decimals: 0)
  end

  def test_to_usd_is_exact
    assert_equal Rational(1, 10_000), Money.to_usd(100)
    assert_equal Rational(-5, 4), Money.to_usd(-1_250_000)
  end

  def test_from_usd
    assert_equal 250_000, Money.from_usd("0.25")
    assert_equal 250_000, Money.from_usd("$0.25")
    assert_equal 100, Money.from_usd(0.0001)
    assert_equal 1_000_000, Money.from_usd(1)
    assert_equal 333_333, Money.from_usd(Rational(1, 3))
    assert_equal 1, Money.from_usd("0.0000005")
  end

  def test_rejects_bad_input
    assert_raises(ArgumentError) { Money.format(1.5) }
    assert_raises(ArgumentError) { Money.from_usd("abc") }
    assert_raises(ArgumentError) { Money.from_usd(Float::NAN) }
    assert_raises(ArgumentError) { Money.from_usd(nil) }
  end
end

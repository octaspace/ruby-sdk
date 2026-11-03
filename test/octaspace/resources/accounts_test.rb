# frozen_string_literal: true

require "test_helper"

class OctaSpace::AccountsResourceTest < Minitest::Test
  def test_balance
    stub_get("/accounts/balance", fixture_path: "account_balance.json")
    balance = test_client.accounts.balance

    assert_equal 1_234_567, balance.balance
    assert_equal "USD", balance.currency
    assert_equal 6, balance.decimals
    assert_equal Rational(1_234_567, 1_000_000), balance.to_usd
    assert_equal "$1.234567", balance.formatted
    refute balance.negative?
  end

  def test_negative_balance_and_other_decimals
    stub_request(:get, "#{StubHelpers::BASE_URL}/accounts/balance")
      .to_return(status: 200, body: '{"balance":-1250,"currency":"USD","decimals":3}')
    balance = test_client.accounts.balance

    assert balance.negative?
    assert_equal "-$1.250", balance.formatted
  end

  def test_balance_requires_key
    assert_raises(OctaSpace::AuthenticationError) { OctaSpace::Client.new.accounts.balance }
  end
end

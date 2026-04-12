# frozen_string_literal: true

require "test_helper"

class OctaSpace::AccountsResourceTest < Minitest::Test
  def setup
    super
    @client = test_client
  end

  def test_profile_returns_response
    stub_get("/accounts", fixture_path: "accounts/show.json")
    response = @client.accounts.profile
    assert response.success?
    assert_equal "acc-123-abc", response.data["account_uuid"]
    assert_equal "user@example.com", response.data["email"]
  end

  def test_balance_returns_response
    stub_get("/accounts/balance", fixture_path: "accounts/balance.json")
    response = @client.accounts.balance
    assert response.success?
    assert response.data.key?("balance")
  end

  def test_generate_wallet_returns_success
    stub_post("/accounts", status: 201, body: '{"wallet":"0xabc123","network":"ETH"}')
    response = @client.accounts.generate_wallet
    assert response.success?
  end

  def test_profile_raises_authentication_error_on_401
    stub_error(:get, "/accounts", status: 401, message: "Unauthorized")
    assert_raises(OctaSpace::AuthenticationError) { @client.accounts.profile }
  end

  def test_profile_raises_rate_limit_error_on_429
    stub_request(:get, "#{StubHelpers::BASE_URL}/accounts")
      .to_return(status: 429, body: "{}", headers: {"Retry-After" => "60"}.merge(json_headers))
    error = assert_raises(OctaSpace::RateLimitError) { @client.accounts.profile }
    assert_equal 60, error.retry_after
  end

  def test_profile_raises_server_error_on_500
    stub_error(:get, "/accounts", status: 500, message: "Internal Server Error")
    assert_raises(OctaSpace::ServerError) { @client.accounts.profile }
  end
end

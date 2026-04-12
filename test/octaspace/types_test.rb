# frozen_string_literal: true

require "test_helper"

class OctaSpace::TypesTest < Minitest::Test
  # --- Node ---

  def test_node_online
    node = OctaSpace::Types::Node.new(
      id: 1, ip: "1.2.3.4", state: "online",
      location: {"city" => "Amsterdam"}, prices: {}, system: {}
    )
    assert node.online?
    refute node.offline?
  end

  def test_node_offline
    node = OctaSpace::Types::Node.new(
      id: 2, ip: "5.6.7.8", state: "offline",
      location: {}, prices: {}, system: {}
    )
    refute node.online?
    assert node.offline?
  end

  def test_node_equality
    attrs = {id: 1, ip: "1.2.3.4", state: "online", location: {}, prices: {}, system: {}}
    assert_equal OctaSpace::Types::Node.new(**attrs), OctaSpace::Types::Node.new(**attrs)
  end

  def test_node_immutability
    node = OctaSpace::Types::Node.new(id: 1, ip: "x", state: "online", location: {}, prices: {}, system: {})
    assert_raises(NoMethodError) { node.id = 99 }
  end

  # --- Balance ---

  def test_balance_to_s
    balance = OctaSpace::Types::Balance.new(amount: "1000000000000000000", currency: "OCTA")
    assert_equal "1000000000000000000 OCTA", balance.to_s
  end

  def test_balance_equality
    b1 = OctaSpace::Types::Balance.new(amount: "100", currency: "OCTA")
    b2 = OctaSpace::Types::Balance.new(amount: "100", currency: "OCTA")
    assert_equal b1, b2
  end

  # --- Account ---

  def test_account_to_s
    account = OctaSpace::Types::Account.new(
      account_uuid: "acc-123", email: "user@example.com",
      avatar: nil, balance: "100"
    )
    assert_equal "OctaSpace Account <user@example.com>", account.to_s
  end

  # --- Session ---

  def test_session_to_s
    session = OctaSpace::Types::Session.new(
      uuid: "sess-abc", service: "mr", app_name: "SD",
      node_id: 1, urls: {}, prices: {}, node_hw: nil
    )
    assert_equal "Session <sess-abc> mr", session.to_s
  end

  def test_session_equality
    attrs = {uuid: "sess-1", service: "mr", app_name: "SD", node_id: 1, urls: {}, prices: {}, node_hw: nil}
    assert_equal OctaSpace::Types::Session.new(**attrs), OctaSpace::Types::Session.new(**attrs)
  end
end

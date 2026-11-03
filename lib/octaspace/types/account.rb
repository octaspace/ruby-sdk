# frozen_string_literal: true

module OctaSpace
  module Types
    # Account balance (+GET /accounts/balance+). It can be negative.
    class Balance < Model
      # @!attribute [r] balance
      #   @return [Integer] amount in units of 10^-decimals of {#currency}
      # @!attribute [r] currency
      #   @return [String] "USD"
      # @!attribute [r] decimals
      #   @return [Integer] decimal places of {#balance} (6: micro-USD)
      attribute :balance, :currency, :decimals

      # @return [Rational] the balance in currency units, exactly
      def to_usd = Money.to_usd(balance, decimals: decimals)

      # @return [String] e.g. "$2.147661"
      def formatted = Money.format(balance, decimals: decimals)

      def negative? = balance.negative?
    end
  end
end

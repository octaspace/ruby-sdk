# frozen_string_literal: true

module OctaSpace
  # Conversions for micro-USD, the integer unit of every price, charge and
  # balance in the API (1 micro-USD = $0.000001).
  #
  # @example
  #   OctaSpace::Money.format(100)          # => "$0.000100"
  #   OctaSpace::Money.to_usd(1_250_000)    # => (5/4)
  #   OctaSpace::Money.from_usd("0.25")     # => 250000
  module Money
    # Number of micro-USD in one dollar
    MICRO_USD_PER_USD = 1_000_000

    module_function

    # Converts an integer amount to dollars, exactly.
    # @param amount [Integer] micro-USD (or units of 10^-decimals)
    # @param decimals [Integer] decimal places of the unit (6 for micro-USD)
    # @return [Rational]
    def to_usd(amount, decimals: 6)
      Rational(integer!(amount), 10**decimals)
    end

    # Converts dollars to micro-USD, rounded to the nearest integer
    # (e.g. for +hosting.set_prices+).
    # @param usd [Integer, Rational, String, Float] a String like "0.25" is
    #   exact; a Float goes through its shortest decimal form
    # @return [Integer]
    def from_usd(usd)
      value = case usd
      when Integer, Rational then usd
      when Float
        raise ArgumentError, "not a finite dollar amount: #{usd}" unless usd.finite?

        Rational(usd.to_s)
      when String
        text = usd.strip.delete_prefix("$")
        raise ArgumentError, "not a dollar amount: #{usd.inspect}" unless text.match?(/\A-?\d+(\.\d+)?\z/)

        Rational(text)
      else
        raise ArgumentError, "not a dollar amount: #{usd.inspect}"
      end
      (value * MICRO_USD_PER_USD).round
    end

    # Formats an integer amount as dollars with all decimal places, using
    # integer arithmetic: 100 → "$0.000100", -1_250_000 → "-$1.250000".
    # @param amount [Integer] micro-USD (or units of 10^-decimals)
    # @param decimals [Integer]
    # @return [String]
    def format(amount, decimals: 6)
      amount = integer!(amount)
      whole, fraction = amount.abs.divmod(10**decimals)
      sign = amount.negative? ? "-" : ""
      return "#{sign}$#{whole}" if decimals.zero?

      "#{sign}$#{whole}.#{fraction.to_s.rjust(decimals, "0")}"
    end

    def integer!(amount)
      raise ArgumentError, "not an integer amount: #{amount.inspect}" unless amount.is_a?(Integer)

      amount
    end
    private_class_method :integer!
  end
end

# frozen_string_literal: true

module OctaSpace
  module Types
    # Value object representing an account balance
    # @note Requires Ruby 3.2+ for Data.define
    Balance = Data.define(:amount, :currency) do
      # @return [String]
      def to_s = "#{amount} #{currency}"
    end
  end
end

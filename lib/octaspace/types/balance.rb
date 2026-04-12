# frozen_string_literal: true

module OctaSpace
  module Types
    # Value object representing an account balance
    Balance = Data.define(:amount, :currency) do
      # @return [String]
      def to_s = "#{amount} #{currency}"
    end
  end
end

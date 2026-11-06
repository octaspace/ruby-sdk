# frozen_string_literal: true

module OctaSpace
  module Resources
    # The account the API key belongs to
    #
    # @example
    #   client.accounts.balance.formatted # => "$12.500000"
    class Accounts < Base
      # Account balance.
      # GET /accounts/balance
      #
      # Also a simple way to check that an API key works. A recent charge or
      # deposit can take a moment to appear.
      # @return [OctaSpace::Types::Balance]
      def balance
        Types::Balance.new(get("/accounts/balance").data)
      end
    end
  end
end

# frozen_string_literal: true

module OctaSpace
  module Resources
    # The account the API key belongs to
    #
    # @example
    #   client.accounts.balance.formatted # => "$2.147661"
    class Accounts < Base
      # Account balance.
      # GET /accounts/balance
      #
      # The API has no "who am I" endpoint, so this is also the way to check
      # that an API key is valid. It is read from a replica, so a recent charge
      # or top-up may show up with a delay.
      # @return [OctaSpace::Types::Balance]
      def balance
        Types::Balance.new(get("/accounts/balance").data)
      end
    end
  end
end

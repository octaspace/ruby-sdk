# frozen_string_literal: true

module OctaSpace
  module Resources
    # Account-related API endpoints
    #
    # @example
    #   client.accounts.profile
    #   client.accounts.balance
    class Accounts < Base
      # Fetch the authenticated user's profile
      # GET /accounts
      # @return [OctaSpace::Response]
      def profile
        get("/accounts")
      end

      # Fetch the authenticated user's balance
      # GET /accounts/balance
      # @return [OctaSpace::Response]
      def balance
        get("/accounts/balance")
      end
    end
  end
end

# frozen_string_literal: true

module Playground
  class AccountsController < BaseController
    def show
      if playground_api_key_present?
        @profile = capture_api_call(label: "octa_client.accounts.profile", path: "/accounts") { octa_client.accounts.profile }
        @balance = capture_api_call(label: "octa_client.accounts.balance", path: "/accounts/balance") { octa_client.accounts.balance }
      else
        @profile = nil
        @balance = nil
      end
    end
  end
end

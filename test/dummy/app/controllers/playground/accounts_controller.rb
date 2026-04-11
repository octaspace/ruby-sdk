# frozen_string_literal: true

module Playground
  class AccountsController < ApplicationController
    def show
      @profile = octa_client.accounts.profile
      @balance = octa_client.accounts.balance
    rescue OctaSpace::AuthenticationError
      @error = "Invalid API key. Set OCTA_API_KEY environment variable."
    rescue OctaSpace::Error => e
      @error = "API error: #{e.message}"
    end
  end
end

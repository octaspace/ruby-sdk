# frozen_string_literal: true

module Playground
  class NetworkController < BaseController
    def show
      @network = capture_api_call(label: "octa_client.network.info", path: "/network") { octa_client.network.info }
    end
  end
end

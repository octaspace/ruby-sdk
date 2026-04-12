# frozen_string_literal: true

module Playground
  class AppsController < BaseController
    def show
      @apps = capture_api_call(label: "octa_client.apps.list", path: "/apps") { octa_client.apps.list }
    end
  end
end

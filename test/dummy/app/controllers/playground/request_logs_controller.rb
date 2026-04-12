# frozen_string_literal: true

module Playground
  class RequestLogsController < BaseController
    def destroy
      clear_request_log!
      redirect_back fallback_location: playground_dashboard_path
    end
  end
end

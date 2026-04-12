# frozen_string_literal: true

module Playground
  class SessionsController < BaseController
    def index
      @active_tab = params[:tab].presence_in(%w[current recent]) || "current"
      load_sessions
      @stop_uuid = params[:stop_uuid].presence
    end

    def stop
      @active_tab = params[:tab].presence_in(%w[current recent]) || "current"
      uuid = params[:uuid].to_s.strip

      if uuid.blank?
        flash[:playground_stop_error] = "Session UUID is required"
        redirect_to playground_sessions_path(tab: @active_tab), status: :see_other
        return
      end

      stop_params = {}
      stop_params[:score] = params[:score].to_i if params[:score].present?

      response = capture_api_call(
        label: "octa_client.services.session(#{uuid}).stop",
        method: "POST",
        path: "/services/#{uuid}/stop"
      ) do
        octa_client.services.session(uuid).stop(**stop_params)
      end

      if response.is_a?(OctaSpace::Error)
        flash[:playground_stop_error] = response.message
      else
        flash[:playground_stop_notice] = {
          "message" => "Session #{uuid} stop request submitted.",
          "request_id" => response.request_id
        }
      end

      redirect_to playground_sessions_path(tab: @active_tab), status: :see_other
    end

    private

    def load_sessions
      @current_sessions = capture_api_call(label: "octa_client.sessions.list", path: "/sessions") { octa_client.sessions.list }
      @recent_sessions = capture_api_call(label: "octa_client.sessions.list(recent: true)", path: "/sessions?recent=true") do
        octa_client.sessions.list(recent: true)
      end
    end
  end
end

# frozen_string_literal: true

module Playground
  class SettingsController < ApplicationController
    def update
      settings = session[:playground_settings] ||= {}

      settings["api_key"] = params[:api_key].to_s if params.key?(:api_key)

      if params.key?(:base_url)
        base_url = params[:base_url].to_s.strip
        base_url.present? ? settings["base_url"] = base_url : settings.delete("base_url")
      end

      if params.key?(:mock_scenario)
        scenario = params[:mock_scenario].to_s
        settings["mock_scenario"] = valid_scenario?(scenario) ? scenario : "real"
      end

      redirect_to safe_return_path
    end

    def destroy
      session.delete(:playground_settings)
      redirect_to safe_return_path
    end

    private

    def valid_scenario?(value)
      OctaSpace::Transport::MockTransport.scenarios.any? { |scenario| scenario[:value] == value }
    end

    def safe_return_path
      path = params[:return_to].to_s
      return playground_dashboard_path unless path.start_with?("/") && !path.start_with?("//")

      path
    end
  end
end

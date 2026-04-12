# frozen_string_literal: true

module Playground
  class NodesController < BaseController
    def index
      @nodes = capture_api_call(label: "octa_client.nodes.list", path: "/nodes") { octa_client.nodes.list }
      @selected_node_id = params[:selected_id].presence || params[:id].presence

      return if @selected_node_id.blank?

      @selected_node = capture_api_call(label: "octa_client.nodes.find(#{@selected_node_id})", path: "/nodes/#{@selected_node_id}") do
        octa_client.nodes.find(@selected_node_id)
      end
    end

    def show
      @node = capture_api_call(label: "octa_client.nodes.find(#{params[:id]})", path: "/nodes/#{params[:id]}") do
        octa_client.nodes.find(params[:id])
      end
    end
  end
end

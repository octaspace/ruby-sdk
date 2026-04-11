# frozen_string_literal: true

module Playground
  class NodesController < ApplicationController
    def index
      @nodes = octa_client.nodes.list
    rescue OctaSpace::Error => e
      @error = "API error: #{e.message}"
    end
  end
end

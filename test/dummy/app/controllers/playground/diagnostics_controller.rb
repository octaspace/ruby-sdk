# frozen_string_literal: true

module Playground
  class DiagnosticsController < ApplicationController
    def show
      @transport_stats = octa_client.transport_stats
      @config          = OctaSpace.configuration
      @rotator_stats   = extract_rotator_stats
    end

    private

    def extract_rotator_stats
      transport = octa_client.instance_variable_get(:@transport)
      rotator   = transport.instance_variable_get(:@rotator)
      rotator&.stats
    end
  end
end

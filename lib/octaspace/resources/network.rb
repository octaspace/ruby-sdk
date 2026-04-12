# frozen_string_literal: true

module OctaSpace
  module Resources
    # Network information endpoint
    #
    # @example
    #   client.network.info
    class Network < Base
      # Fetch combined network information (blockchain, market, nodes, power, etc.)
      # GET /network
      # @return [OctaSpace::Response]
      def info
        get("/network")
      end
    end
  end
end

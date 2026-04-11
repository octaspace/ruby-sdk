# frozen_string_literal: true

module OctaSpace
  module Resources
    # Network statistics endpoints
    #
    # @example
    #   client.network.stats
    #   client.network.power
    class Network < Base
      # Fetch network statistics
      # GET /network/stats
      # @return [OctaSpace::Response]
      def stats
        get("/network/stats")
      end

      # Fetch network power metrics
      # GET /network/power
      # @return [OctaSpace::Response]
      def power
        get("/network/power")
      end
    end
  end
end

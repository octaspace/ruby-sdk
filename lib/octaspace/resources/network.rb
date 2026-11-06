# frozen_string_literal: true

module OctaSpace
  module Resources
    # Platform statistics; no API key needed
    #
    # @example
    #   client.network.info.nodes.online
    class Network < Base
      # Platform statistics snapshot.
      # GET /network
      #
      # Raises {OctaSpace::ServiceUnavailableError} while it is unavailable.
      # @return [OctaSpace::Types::Network]
      def info
        Types::Network.new(get("/network", auth: :none).data)
      end
    end
  end
end

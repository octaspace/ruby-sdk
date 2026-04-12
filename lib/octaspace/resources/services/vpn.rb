# frozen_string_literal: true

module OctaSpace
  module Resources
    class Services
      # VPN service endpoints
      #
      # @example
      #   client.services.vpn.list
      #   client.services.vpn.create(node_id: 123)
      class Vpn < Base
        # List active VPN sessions
        # GET /services/vpn
        # @param params [Hash] optional filter params
        # @return [OctaSpace::Response]
        def list(**params)
          get("/services/vpn", params:)
        end

        # Create (start) a VPN session
        # POST /services/vpn
        # @param attrs [Hash] VPN parameters
        # @return [OctaSpace::Response]
        def create(**attrs)
          post("/services/vpn", body: attrs)
        end
      end
    end
  end
end

# frozen_string_literal: true

module OctaSpace
  module Resources
    module Services
      # Machine Rental (MR) service endpoints
      #
      # @example
      #   client.services.mr.list
      #   client.services.mr.create(node_id: 123, app_id: 5)
      class MachineRental < Base
        # List available / active machine rentals
        # GET /services/mr
        # @param params [Hash] optional filter params
        # @return [OctaSpace::Response]
        def list(**params)
          get("/services/mr", params: params)
        end

        # Create (start) a machine rental
        # POST /services/mr
        # @param attrs [Hash] rental parameters
        # @return [OctaSpace::Response]
        def create(**attrs)
          post("/services/mr", body: attrs)
        end
      end
    end
  end
end

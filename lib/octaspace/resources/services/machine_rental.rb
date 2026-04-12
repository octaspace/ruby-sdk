# frozen_string_literal: true

module OctaSpace
  module Resources
    class Services
      # Machine Rental (MR) service endpoints
      #
      # @example
      #   client.services.mr.list
      #   client.services.mr.create(
      #     node_id: 123,
      #     disk_size: 10,
      #     image: "ubuntu:24.04",
      #     app: "249b4cb3-3db1-4c06-98a4-772ba88cd81c"
      #   )
      class MachineRental < Base
        # List available / active machine rentals
        # GET /services/mr
        # @param params [Hash] optional filter params
        # @return [OctaSpace::Response]
        def list(**params)
          get("/services/mr", params:)
        end

        # Create (start) a machine rental
        # POST /services/mr
        # @param attrs [Hash] rental parameters
        # @return [OctaSpace::Response]
        def create(**attrs)
          item = {
            id: 0,
            node_id: attrs.fetch(:node_id),
            disk_size: attrs.fetch(:disk_size),
            image: attrs.fetch(:image),
            app: attrs[:app].to_s,
            envs: attrs[:envs] || {},
            ports: attrs[:ports] || [],
            http_ports: attrs[:http_ports] || [],
            start_command: attrs[:start_command].to_s,
            entrypoint: attrs[:entrypoint].to_s
          }

          post("/services/mr", body: [item])
        end
      end
    end
  end
end

# frozen_string_literal: true

module OctaSpace
  module Resources
    class Services
      # Render service endpoints
      #
      # @example
      #   client.services.render.list
      #   client.services.render.create(node_id: 123, disk_size: 100)
      class Render < Base
        # List render jobs
        # GET /services/render
        # @param params [Hash] optional filter params
        # @return [OctaSpace::Response]
        def list(**params)
          get("/services/render", params:)
        end

        # Create (start) a render job
        # POST /services/render
        # @param attrs [Hash] render job parameters
        # @return [OctaSpace::Response]
        def create(**attrs)
          post("/services/render", body: attrs)
        end
      end
    end
  end
end

# frozen_string_literal: true

module OctaSpace
  module Resources
    # Node-related API endpoints
    #
    # @example
    #   client.nodes.list
    #   client.nodes.find(123)
    #   client.nodes.reboot(123)
    #   client.nodes.update_prices(123, gpu_hour: 0.5, cpu_hour: 0.1)
    class Nodes < Base
      # List all nodes
      # GET /nodes
      # @param params [Hash] optional filter/pagination params
      # @return [OctaSpace::Response]
      def list(**params)
        get("/nodes", params:)
      end

      # Fetch a single node by ID
      # GET /nodes/:id
      # @param id [Integer, String]
      # @return [OctaSpace::Response]
      def find(id)
        get("/nodes/#{encode(id)}")
      end

      # Download node identity file (binary response)
      # GET /nodes/:id/ident
      # @param id [Integer, String]
      # @return [OctaSpace::Response]
      def download_ident(id)
        get("/nodes/#{encode(id)}/ident")
      end

      # Download node logs (binary response)
      # GET /nodes/:id/logs
      # @param id [Integer, String]
      # @return [OctaSpace::Response]
      def download_logs(id)
        get("/nodes/#{encode(id)}/logs")
      end

      # Update node pricing
      # PATCH /nodes/:id/prices
      # @param id [Integer, String]
      # @param prices [Hash] e.g. { gpu_hour: 0.5, cpu_hour: 0.1 }
      # @return [OctaSpace::Response]
      def update_prices(id, **prices)
        patch("/nodes/#{encode(id)}/prices", body: prices)
      end

      # Reboot a node
      # GET /nodes/:id/reboot
      # @param id [Integer, String]
      # @return [OctaSpace::Response]
      def reboot(id)
        get("/nodes/#{encode(id)}/reboot")
      end
    end
  end
end

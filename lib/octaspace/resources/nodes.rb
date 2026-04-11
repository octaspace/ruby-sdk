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
        get("/nodes", params: params)
      end

      # Fetch a single node by ID
      # GET /nodes/:id
      # @param id [Integer, String]
      # @return [OctaSpace::Response]
      def find(id)
        get("/nodes/#{id}")
      end

      # Download node identity file (binary response)
      # GET /nodes/:id/ident
      # @param id [Integer, String]
      # @return [OctaSpace::Response]
      def download_ident(id)
        get("/nodes/#{id}/ident")
      end

      # Download node logs (binary response)
      # GET /nodes/:id/logs
      # @param id [Integer, String]
      # @return [OctaSpace::Response]
      def download_logs(id)
        get("/nodes/#{id}/logs")
      end

      # Update node pricing
      # PUT /nodes/:id/prices
      # @param id [Integer, String]
      # @param prices [Hash] e.g. { gpu_hour: 0.5, cpu_hour: 0.1 }
      # @return [OctaSpace::Response]
      def update_prices(id, **prices)
        put("/nodes/#{id}/prices", body: prices)
      end

      # Reboot a node
      # POST /nodes/:id/reboot
      # @param id [Integer, String]
      # @return [OctaSpace::Response]
      def reboot(id)
        post("/nodes/#{id}/reboot")
      end
    end
  end
end

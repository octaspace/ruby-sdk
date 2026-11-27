# frozen_string_literal: true

module OctaSpace
  module Resources
    # Render nodes: listing and start (single and batch).
    #
    # @example
    #   node = client.render.list.max_by(&:blender_score)
    #   uuid = client.render.start(node_number: node.node_number)
    class Render < Base
      START_PARAMS = %i[node_number].freeze

      # Nodes available for render.
      # GET /services/render
      #
      # Works without an API key, but is then refreshed about once an hour;
      # with a key it is at most 10 seconds old.
      # @return [Array<OctaSpace::Types::RenderMachine>]
      def list
        Types::RenderMachine.wrap_all(normalize_machines(get("/services/render", auth: :optional).data))
      end

      # Rents a node as a render node, billed by the hour until stopped.
      # POST /services/render
      #
      # While render is temporarily unavailable this raises
      # {OctaSpace::ServiceUnavailableError} (503). Never retried automatically.
      # @param node_number [String]
      # @return [String] the session uuid
      def start(node_number:)
        post("/services/render", body: {node_number: node_number}).data.fetch("uuid")
      end

      # Rents several render nodes at once.
      # POST /services/render
      #
      # Unlike {#start}, a temporarily unavailable service is reported in each
      # item's +reason+ instead of raising {OctaSpace::ServiceUnavailableError}.
      # @param items [Array<Hash>] each +{node_number:}+ with an optional +:id+
      # @return [Array<OctaSpace::Types::BatchResult>]
      def start_batch(items)
        Types::BatchResult.wrap_all(post("/services/render", body: batch_items(items, START_PARAMS)).data)
      end
    end
  end
end

# frozen_string_literal: true

module OctaSpace
  module Resources
    # Nodes the account hosts: state, prices and maintenance
    #
    # @example
    #   client.hosting.nodes.each { |node| puts "#{node.number} #{node.status}" }
    #   client.hosting.set_prices("7KQ4-M2XD-4", base: OctaSpace::Money.from_usd("0.25"))
    #   client.hosting.start_maintenance("7KQ4-M2XD-4")
    class Hosting < Base
      PRICE_FIELDS = %i[base storage traffic min_rent_minutes].freeze

      # Integer GPU fields of +system.gpus+, read as numbers
      HOSTING_GPU_FIELDS = (GPU_INTEGER_FIELDS + %w[mem_free_mb fan_speed gpu_temperature gpu_utilization power_draw_watt]).freeze

      # Online nodes of the account with their state, hardware and prices.
      # GET /hosting/nodes
      #
      # Offline nodes are not listed. A node that runs only VPN sessions stays
      # "idle".
      # @return [Array<OctaSpace::Types::HostingNode>]
      def nodes
        Types::HostingNode.wrap_all(normalize_nodes(transport.get("/hosting/nodes").data))
      end

      # One online node of the account.
      # GET /hosting/nodes/{number}
      #
      # Raises {OctaSpace::NotFoundError} when the node is offline, does not
      # exist or is not yours, and {OctaSpace::ValidationError} for a
      # malformed number.
      # @param number [String] node number; case and dashes are ignored
      # @return [OctaSpace::Types::HostingNode]
      def get(number)
        Types::HostingNode.wrap(normalize_nodes([transport.get("/hosting/nodes/#{encode(number)}").data]).first)
      end

      # Updates some prices of a node.
      # PATCH /hosting/nodes/{number}/prices
      #
      # Never retried automatically.
      # Only the given fields are sent; at least one is required. Amounts are
      # integer micro-USD (convert dollars with {OctaSpace::Money.from_usd}).
      # Ranges: base and traffic 100..1_000_000_000, storage 0..1_000_000_000,
      # min_rent_minutes 0..60. The API refuses other values with
      # {OctaSpace::ValidationError}, and an unknown node with
      # {OctaSpace::NotFoundError}.
      #
      # The listings (+hosting.nodes+, +compute.list+) show new prices within
      # seconds.
      #
      # @param number [String] node number; case and dashes are ignored
      # @param base [Integer, nil]
      # @param storage [Integer, nil]
      # @param traffic [Integer, nil]
      # @param min_rent_minutes [Integer, nil]
      # @return [nil]
      def set_prices(number, **prices)
        body = compact_params(prices, PRICE_FIELDS)
        raise ArgumentError, "set_prices needs at least one of #{PRICE_FIELDS.join(", ")}" if body.empty?

        body.each do |field, value|
          raise ArgumentError, "#{field} must be an Integer (micro-USD or minutes), got #{value.inspect}" unless value.is_a?(Integer)
        end
        patch("/hosting/nodes/#{encode(number)}/prices", body: body)
        nil
      end

      # Puts a node in maintenance: it is no longer offered for new rentals;
      # running sessions go on and their renters are notified. Works for an
      # offline node too, and calling it again changes nothing.
      # PUT /hosting/nodes/{number}/maintenance
      #
      # Raises {OctaSpace::NotFoundError} when the node is not yours or does
      # not exist, and {OctaSpace::ValidationError} for a malformed number.
      # @param number [String] node number
      # @return [nil]
      def start_maintenance(number)
        put(maintenance_path(number))
        nil
      end

      # Offers a node for rent again. Calling it again changes nothing.
      # DELETE /hosting/nodes/{number}/maintenance
      #
      # Raises the same errors as {#start_maintenance}.
      # @param number [String] node number
      # @return [nil]
      def end_maintenance(number)
        delete(maintenance_path(number))
        nil
      end

      private

      def maintenance_path(number) = "/hosting/nodes/#{encode(number)}/maintenance"

      # "null" strings become nil and numeric GPU strings in +system.gpus+ numbers
      def normalize_nodes(data)
        nodes = JsonNull.null_strings!(Array(data))
        JsonNull.gpu_numbers!(nodes.filter_map { |node| node["system"] if node.is_a?(Hash) }, HOSTING_GPU_FIELDS)
        nodes
      end
    end
  end
end

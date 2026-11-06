# frozen_string_literal: true

module OctaSpace
  module Resources
    # Nodes the account hosts
    #
    # @example
    #   client.hosting.nodes.each { |node| puts "#{node.number} #{node.status}" }
    #   client.hosting.set_prices("7KQ4-M2XD-4", base: OctaSpace::Money.from_usd("0.25"))
    class Hosting < Base
      PRICE_FIELDS = %i[base storage traffic min_rent_minutes].freeze

      # Integer GPU fields of +system.gpus+, read as numbers
      HOSTING_GPU_FIELDS = (GPU_INTEGER_FIELDS + %w[mem_free_mb fan_speed gpu_temperature gpu_utilization power_draw_watt]).freeze

      # Online nodes of the account with their state, hardware and prices.
      # GET /hosting/nodes
      #
      # Offline nodes are not listed.
      # @return [Array<OctaSpace::Types::HostingNode>]
      def nodes
        data = JsonNull.null_strings!(Array(get("/hosting/nodes").data))
        JsonNull.gpu_numbers!(data.map { |node| node.is_a?(Hash) ? node["system"] : nil }.compact, HOSTING_GPU_FIELDS)
        Types::HostingNode.wrap_all(data)
      end

      # Updates some prices of a node.
      # PATCH /hosting/nodes/{number}/prices
      #
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
    end
  end
end

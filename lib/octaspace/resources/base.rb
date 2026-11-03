# frozen_string_literal: true

require "uri"

module OctaSpace
  module Resources
    # Base class for all API resource groups
    #
    # Delegates HTTP methods to the transport layer and provides
    # helpers shared by the resources.
    class Base
      # Integer fields of a listing's GPU objects that nodes may send as strings
      GPU_INTEGER_FIELDS = %w[mem_total_mb pcie_link_gen pcie_link_width core_clock mem_clock power_limit].freeze

      # @param transport [OctaSpace::Transport::Base]
      def initialize(transport)
        @transport = transport
      end

      private

      attr_reader :transport

      def get(path, **opts) = transport.get(path, **opts)
      def post(path, **opts) = transport.post(path, **opts)
      def patch(path, **opts) = transport.patch(path, **opts)

      # Encode a single path segment to prevent path traversal
      # @param segment [String, Integer]
      # @return [String]
      def encode(segment)
        URI.encode_www_form_component(segment.to_s)
      end

      # Keeps only the given keys whose value is not nil, so a request never
      # carries fields the caller did not set: the API refuses unknown fields,
      # and treats an absent ssh/fm differently from false.
      def compact_params(params, allowed)
        params = params.to_h.transform_keys(&:to_sym)
        unknown = params.keys - allowed
        raise ArgumentError, "unknown parameter(s): #{unknown.join(", ")}" if unknown.any?

        params.compact
      end

      # Gives every batch item an id: its own, or its position in the array.
      # Raises ArgumentError when two items end up with the same id (their
      # results could not be told apart, and each started session costs money).
      def batch_items(items, allowed)
        raise ArgumentError, "a batch needs at least one item" if Array(items).empty?

        seen = {}
        Array(items).each_with_index.map do |item, index|
          raise ArgumentError, "batch item #{index} must be a Hash" unless item.is_a?(Hash)

          params = item.to_h.transform_keys(&:to_sym)
          id = params.key?(:id) ? params.delete(:id) : index
          raise ArgumentError, "duplicate batch id #{id.inspect}: give every item a unique id, or none to all of them" if seen.key?(id)

          seen[id] = true
          {id: id, **compact_params(params, allowed)}
        end
      end

      # Machine listings: "null" strings become nil and string GPU integers
      # become numbers, so one misreporting node does not break the listing.
      def normalize_machines(data)
        JsonNull.gpu_numbers!(JsonNull.null_strings!(Array(data)), GPU_INTEGER_FIELDS)
      end
    end
  end
end

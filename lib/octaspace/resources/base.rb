# frozen_string_literal: true

require "uri"

module OctaSpace
  module Resources
    # Base class for all API resource groups
    #
    # Delegates HTTP methods to the transport layer and provides
    # a clean DSL for subclasses.
    class Base
      # @param transport [OctaSpace::Transport::Base]
      def initialize(transport)
        @transport = transport
      end

      private

      attr_reader :transport

      def get(path, **opts) = transport.get(path, **opts)
      def post(path, **opts) = transport.post(path, **opts)
      def put(path, **opts) = transport.put(path, **opts)
      def patch(path, **opts) = transport.patch(path, **opts)
      def delete(path, **opts) = transport.delete(path, **opts)

      # Encode a single path segment to prevent path traversal
      # @param segment [String, Integer]
      # @return [String]
      def encode(segment)
        URI.encode_www_form_component(segment.to_s)
      end
    end
  end
end

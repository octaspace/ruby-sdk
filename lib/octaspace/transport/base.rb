# frozen_string_literal: true

module OctaSpace
  module Transport
    # Abstract base class for HTTP transports
    #
    # Concrete implementations: FaradayTransport (standard) and
    # PersistentTransport (keep-alive with connection pooling).
    class Base
      # @param path [String]
      # @param params [Hash]
      # @param headers [Hash]
      # @return [OctaSpace::Response]
      def get(path, params: {}, headers: {})
        raise NotImplementedError, "#{self.class}#get not implemented"
      end

      # @param path [String]
      # @param body [Hash, nil]
      # @param headers [Hash]
      # @return [OctaSpace::Response]
      def post(path, body: nil, headers: {})
        raise NotImplementedError, "#{self.class}#post not implemented"
      end

      # @param path [String]
      # @param body [Hash, nil]
      # @param headers [Hash]
      # @return [OctaSpace::Response]
      def put(path, body: nil, headers: {})
        raise NotImplementedError, "#{self.class}#put not implemented"
      end

      # @param path [String]
      # @param body [Hash, nil]
      # @param headers [Hash]
      # @return [OctaSpace::Response]
      def patch(path, body: nil, headers: {})
        raise NotImplementedError, "#{self.class}#patch not implemented"
      end

      # @param path [String]
      # @param params [Hash]
      # @param headers [Hash]
      # @return [OctaSpace::Response]
      def delete(path, params: {}, headers: {})
        raise NotImplementedError, "#{self.class}#delete not implemented"
      end
    end
  end
end

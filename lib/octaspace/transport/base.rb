# frozen_string_literal: true

module OctaSpace
  module Transport
    # Abstract base class for HTTP transports
    #
    # Concrete implementations: FaradayTransport (standard) and
    # PersistentTransport (keep-alive with connection pooling). A custom
    # transport (e.g. for tests) only needs to implement {#request}.
    class Base
      # Perform a request and return the response, or raise an OctaSpace::Error.
      #
      # @param method [Symbol] :get, :post, :patch, :put or :delete
      # @param path [String] API path, e.g. "/services/compute"
      # @param params [Hash] query parameters (nil values are dropped)
      # @param body [Hash, Array, nil] JSON body
      # @param auth [Symbol] :required (raise AuthenticationError without a key),
      #   :optional (send the key when configured) or :none (never send it)
      # @param idempotent [Boolean] allow retries for a non-GET request the API
      #   documents as idempotent
      # @return [OctaSpace::Response]
      def request(method, path, params: {}, body: nil, auth: :required, idempotent: false)
        raise NotImplementedError, "#{self.class}#request not implemented"
      end

      def get(path, params: {}, auth: :required)
        request(:get, path, params: params, auth: auth)
      end

      def post(path, body: nil, auth: :required, idempotent: false)
        request(:post, path, body: body, auth: auth, idempotent: idempotent)
      end

      def patch(path, body: nil, auth: :required)
        request(:patch, path, body: body, auth: auth)
      end

      def put(path, body: nil, auth: :required)
        request(:put, path, body: body, auth: auth)
      end

      def delete(path, params: {}, auth: :required)
        request(:delete, path, params: params, auth: auth)
      end

      # @return [OctaSpace::RateLimit, nil] rate limit state of the most recent
      #   response that carried RateLimit-* headers
      def rate_limit = nil
    end
  end
end

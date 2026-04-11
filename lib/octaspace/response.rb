# frozen_string_literal: true

module OctaSpace
  # Wraps a raw Faraday response, providing a stable SDK interface
  class Response
    attr_reader :status, :headers, :body, :data

    # @param faraday_response [Faraday::Response]
    def initialize(faraday_response)
      @status  = faraday_response.status
      @headers = faraday_response.headers
      @body    = faraday_response.body
      # Faraday :json middleware parses JSON body into a Hash/Array automatically
      @data    = faraday_response.body
    end

    # @return [Boolean] true for 2xx status codes
    def success?      = (200..299).cover?(status)

    # @return [Boolean] true for 4xx status codes
    def client_error? = (400..499).cover?(status)

    # @return [Boolean] true for 5xx status codes
    def server_error? = (500..599).cover?(status)

    # @return [Boolean] true for any non-2xx error
    def error?        = client_error? || server_error?

    # @return [String, nil] X-Request-Id header value
    def request_id    = headers["x-request-id"]

    # @return [Integer, nil] Retry-After header value in seconds
    def retry_after   = headers["retry-after"]&.to_i

    def to_s
      "#<OctaSpace::Response status=#{status}>"
    end
    alias inspect to_s
  end
end

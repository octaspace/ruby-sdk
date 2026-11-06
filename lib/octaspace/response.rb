# frozen_string_literal: true

require "time"

module OctaSpace
  # Rate limit state reported by the API in the +RateLimit-Limit+,
  # +RateLimit-Remaining+ and +RateLimit-Reset+ headers (IETF draft format,
  # no +X-+ prefix).
  #
  # The API keeps separate windows (anonymous per IP, authenticated per
  # account, and a stricter one for starting and restarting services), so the
  # values describe the window of the request they came from. When a request
  # is refused with 429, prefer {ApiError#retry_after}: a per-session cooldown
  # can demand a longer wait than the window reset.
  RateLimit = Data.define(:limit, :remaining, :reset) do
    # @param headers [Hash] response headers (case-insensitive lookup)
    # @return [RateLimit, nil] nil when no header is present or one is not an integer
    def self.from_headers(headers)
      values = %w[limit remaining reset].to_h do |name|
        raw = headers["ratelimit-#{name}"].to_s.strip
        return nil unless raw.empty? || raw.match?(/\A\d+\z/)

        [name.to_sym, raw.empty? ? nil : raw.to_i]
      end
      values.values.all?(&:nil?) ? nil : new(**values)
    end
  end

  # An HTTP response of the API, with the JSON body already parsed
  class Response
    # @return [Integer] HTTP status
    attr_reader :status

    # @return [Hash] response headers (case-insensitive when built by the SDK transport)
    attr_reader :headers

    # @return [String] raw response body
    attr_reader :body

    # @return [Hash, Array, nil] parsed JSON body; nil for an empty body (e.g. 202/204)
    attr_reader :data

    # @param status [Integer]
    # @param headers [Hash]
    # @param body [String, nil] raw body
    # @param data [Hash, Array, nil] parsed JSON body
    def initialize(status:, headers: {}, body: nil, data: nil)
      @status = status
      @headers = headers
      @body = body.to_s
      @data = data
    end

    # @return [Boolean] true for 2xx status codes
    def success? = (200..299).cover?(status)

    # @return [Boolean] true for 4xx status codes
    def client_error? = (400..499).cover?(status)

    # @return [Boolean] true for 5xx status codes
    def server_error? = (500..599).cover?(status)

    # @return [Boolean] true for any non-2xx error
    def error? = client_error? || server_error?

    # @return [String, nil] X-Request-Id header value
    def request_id = headers["x-request-id"]

    # Retry-After header as whole seconds: delta-seconds (a fractional value is
    # rounded up) or an HTTP date.
    # @return [Integer, nil]
    def retry_after
      raw = headers["retry-after"].to_s.strip
      return nil if raw.empty?
      return raw.to_f.ceil if raw.match?(/\A\d+(\.\d+)?\z/)
      return nil unless raw.match?(/\A[A-Za-z]{3}, \d{2} [A-Za-z]{3} \d{4} \d{2}:\d{2}:\d{2} GMT\z/)

      [(Time.httpdate(raw) - Time.now).ceil, 0].max
    rescue ArgumentError
      nil
    end

    # @return [OctaSpace::RateLimit, nil] values of the RateLimit-* headers
    def rate_limit = RateLimit.from_headers(headers)

    def to_s
      "#<OctaSpace::Response status=#{status}>"
    end
    alias_method :inspect, :to_s
  end
end

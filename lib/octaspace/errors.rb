# frozen_string_literal: true

module OctaSpace
  # Base error class for all OctaSpace SDK errors
  class Error < StandardError
    # @return [OctaSpace::Response, nil] the response that caused the error
    attr_reader :response

    # @return [Integer, nil] HTTP status
    attr_reader :status

    # @return [String, nil] X-Request-Id of the response
    attr_reader :request_id

    def initialize(message = nil, response: nil)
      @response = response
      @status = response&.status
      @request_id = response&.request_id
      super(message || "OctaSpace API error")
    end
  end

  # Raised when SDK is misconfigured (e.g., missing required gems for persistent mode)
  class ConfigurationError < Error; end

  # Network-level errors (before HTTP response is received)
  class NetworkError < Error; end
  class ConnectionError < NetworkError; end
  class TimeoutError < NetworkError; end

  # Raised by sessions.wait_ready / wait_stopped when the timeout runs out
  class WaitTimeoutError < TimeoutError; end

  # An HTTP 4xx/5xx response from the API, or a 2xx response the SDK could not
  # read. The next API answers errors as +{"message": "..."}+; the message is
  # used as the exception message.
  class ApiError < Error
    # @return [Integer, nil] seconds to wait before retrying (Retry-After header)
    attr_reader :retry_after

    # @return [OctaSpace::RateLimit, nil] rate limit state of this response
    attr_reader :rate_limit

    def initialize(message = nil, response: nil)
      @retry_after = response&.retry_after
      @rate_limit = response&.rate_limit
      super
    end

    # @return [Object, nil] parsed response body
    def body = response&.data
  end

  # 400 or 422: the request was rejected as invalid; the message says why
  # (for example "tail must be 1..1000" or "Invalid node number").
  class ValidationError < ApiError; end

  # 401: the API key is missing or invalid. The next API expects
  # +Authorization: Bearer octa_ak_…+; legacy account tokens are refused.
  # Also raised before any request when an endpoint needs a key and the
  # client has none.
  class AuthenticationError < ApiError; end

  # 403 Forbidden
  class PermissionError < ApiError; end

  # 404: the resource does not exist. For a session this also means it has
  # stopped: the API only reports running sessions.
  class NotFoundError < ApiError; end

  # Raised by sessions.wait_ready when the session disappears (404) while it
  # is waited for: it stopped, for example because its SSH setup failed. A
  # stopped session's logs are no longer available.
  class SessionStoppedError < NotFoundError; end

  # 409: the operation conflicts with the current state, e.g. restarting a
  # session that is still starting or restarting.
  class ConflictError < ApiError; end

  # 429: too many requests. Wait {#retry_after} seconds before retrying.
  class RateLimitError < ApiError; end

  # 5xx Server Errors
  class ServerError < ApiError; end
  class BadGatewayError < ServerError; end # 502

  # 503: a backend the API depends on (render nodes, statistics, …) is
  # temporarily unavailable. The request itself was fine; retry later.
  class ServiceUnavailableError < ServerError; end

  class GatewayTimeoutError < ServerError; end # 504

  # HTTP status code → exception class mapping
  STATUS_ERRORS = {
    400 => ValidationError,
    401 => AuthenticationError,
    403 => PermissionError,
    404 => NotFoundError,
    409 => ConflictError,
    422 => ValidationError,
    429 => RateLimitError,
    502 => BadGatewayError,
    503 => ServiceUnavailableError,
    504 => GatewayTimeoutError
  }.freeze

  # Longest error message kept from a response body (e.g. an HTML error page)
  MAX_ERROR_MESSAGE_LENGTH = 512

  # Build the appropriate error for a given Response
  # @param response [OctaSpace::Response]
  # @param api_key [String, nil] the key the request was sent with, for a hint on 401
  # @return [OctaSpace::ApiError] subclass instance
  def self.error_for(response, api_key: nil)
    klass = STATUS_ERRORS.fetch(response.status) do
      response.server_error? ? ServerError : ApiError
    end
    message = error_message(response)
    if response.status == 401 && api_key && !api_key.start_with?(API_KEY_PREFIX)
      message += " (the next API expects a key starting with \"#{API_KEY_PREFIX}\"; " \
                 "legacy account tokens are not accepted)"
    end
    klass.new(message, response: response)
  end

  # @api private
  def self.error_message(response)
    data = response.data
    if data.is_a?(Hash)
      text = data.values_at("message", "error", "detail").find { |v| v.is_a?(String) && !v.empty? }
    end
    text ||= response.body.to_s.strip
    text = "Request failed with status #{response.status}" if text.empty?
    (text.length > MAX_ERROR_MESSAGE_LENGTH) ? "#{text[0, MAX_ERROR_MESSAGE_LENGTH]}…" : text
  end
end

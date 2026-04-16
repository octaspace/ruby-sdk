# frozen_string_literal: true

module OctaSpace
  # Base error class for all OctaSpace SDK errors
  class Error < StandardError
    attr_reader :response, :status, :request_id

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

  # API-level errors (HTTP response received, but indicates failure)
  class ApiError < Error; end

  # Domain-level rejection where transport succeeded but the provision request
  # was rejected by the API payload contract.
  class ProvisionRejectedError < Error
    attr_reader :rejections

    def initialize(message = nil, response: nil, rejections: [])
      @rejections = Array(rejections)
      super(message || build_message(@rejections), response: response)
    end

    private

    def build_message(rejections)
      first_reason =
        rejections.filter_map do |item|
          next unless item.is_a?(Hash)

          item["reason"] || item[:reason]
        end.first

      return "Provision request rejected" if first_reason.to_s.empty?

      "Provision request rejected: #{first_reason}"
    end
  end

  # 401 Unauthorized
  class AuthenticationError < ApiError; end

  # 403 Forbidden
  class PermissionError < ApiError; end

  # 404 Not Found
  class NotFoundError < ApiError; end

  # 422 Unprocessable Entity
  class ValidationError < ApiError; end

  # 429 Too Many Requests — includes Retry-After header value
  class RateLimitError < ApiError
    attr_reader :retry_after

    def initialize(message = nil, response: nil)
      @retry_after = response&.retry_after
      super
    end
  end

  # 5xx Server Errors
  class ServerError < ApiError; end
  class BadGatewayError < ServerError; end # 502
  class ServiceUnavailableError < ServerError; end # 503
  class GatewayTimeoutError < ServerError; end # 504

  # HTTP status code → exception class mapping
  STATUS_ERRORS = {
    401 => AuthenticationError,
    403 => PermissionError,
    404 => NotFoundError,
    422 => ValidationError,
    429 => RateLimitError,
    502 => BadGatewayError,
    503 => ServiceUnavailableError,
    504 => GatewayTimeoutError
  }.freeze

  # Build the appropriate error for a given Response
  # @param response [OctaSpace::Response]
  # @return [OctaSpace::ApiError] subclass instance
  def self.error_for(response)
    klass = STATUS_ERRORS.fetch(response.status) do
      response.server_error? ? ServerError : ApiError
    end
    klass.new(response: response)
  end
end

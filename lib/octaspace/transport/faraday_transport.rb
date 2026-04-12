# frozen_string_literal: true

require "faraday"
require "faraday/retry"

module OctaSpace
  module Transport
    # Standard HTTP transport built on Faraday
    #
    # Features:
    # - Automatic JSON request/response encoding
    # - Configurable retry with exponential backoff + jitter
    # - URL rotation / failover across multiple base_urls
    # - on_request / on_response hooks
    # - Typed exception hierarchy mapped from HTTP status codes
    #
    # @example
    #   config = OctaSpace::Configuration.new
    #   config.api_key = "my_key"
    #   transport = OctaSpace::Transport::FaradayTransport.new(config)
    #   response = transport.get("/nodes")
    class FaradayTransport < Base
      RETRY_STATUSES = [408, 429, 500, 502, 503, 504].freeze
      RETRY_METHODS = %i[get head options put delete].freeze

      def initialize(config)
        @config = config
        @rotator = (config.urls.size > 1) ? Middleware::UrlRotator.new(config.urls) : nil
        # Single URL: build one connection upfront for reuse
        @connection = build_connection(config.urls.first) unless @rotator
      end

      def get(path, params: {}, headers: {})
        request(:get, path, params: params, headers: headers)
      end

      def post(path, body: nil, headers: {})
        request(:post, path, body: body, headers: headers)
      end

      def put(path, body: nil, headers: {})
        request(:put, path, body: body, headers: headers)
      end

      def patch(path, body: nil, headers: {})
        request(:patch, path, body: body, headers: headers)
      end

      def delete(path, params: {}, headers: {})
        request(:delete, path, params: params, headers: headers)
      end

      private

      attr_reader :config

      # Execute HTTP request with optional URL rotation
      def request(method, path, params: {}, body: nil, headers: {})
        invoke_hook(config.on_request, {method: method, path: path, params: params})

        with_failover do |base_url|
          conn = @rotator ? build_connection(base_url) : @connection
          begin
            faraday_resp = execute(conn, method, path, params: params, body: body, headers: headers)
          rescue Faraday::ConnectionFailed => e
            raise ConnectionError, e.message
          rescue Faraday::TimeoutError => e
            raise TimeoutError, e.message
          end
          response = Response.new(faraday_resp)
          invoke_hook(config.on_response, response)
          raise OctaSpace.error_for(response) if response.error?
          response
        end
      end

      # Execute a single Faraday request
      def execute(conn, method, path, params: {}, body: nil, headers: {})
        conn.public_send(method, path) do |req|
          req.headers.merge!(default_headers.merge(headers))
          req.params.merge!(params) if params.any?
          req.body = body.to_json if body
        end
      end

      # Try each URL in rotation; mark failures and retry
      def with_failover(&block)
        urls = @rotator ? @config.urls.dup : [nil]
        tried = []
        last_error = nil

        urls.each do |url|
          next if tried.include?(url)
          tried << url

          begin
            return yield(url)
          rescue ConnectionError, TimeoutError => e
            last_error = e
            @rotator&.mark_failed(url)
          end
        end

        raise last_error || ConnectionError.new("All API endpoints unavailable")
      end

      # Build a Faraday connection for a given base URL
      def build_connection(base_url)
        Faraday.new(url: base_url, request: request_options, ssl: ssl_options) do |f|
          f.request :json
          f.request :retry, retry_options
          f.response :json, content_type: /\bjson/
          f.response :logger, config.logger, {headers: true, bodies: false} if config.logger
          configure_adapter(f)
        end
      end

      # Override in PersistentTransport
      def configure_adapter(builder)
        builder.adapter :net_http
      end

      def default_headers
        headers = {
          "User-Agent" => config.user_agent,
          "Accept" => "application/json"
        }
        headers["Authorization"] = config.api_key if config.api_key && !config.api_key.empty?
        headers
      end

      def retry_options
        {
          max: config.max_retries,
          interval: config.retry_interval,
          interval_randomness: 0.5,
          backoff_factor: config.backoff_factor,
          retry_statuses: RETRY_STATUSES,
          methods: RETRY_METHODS
        }
      end

      def request_options
        {
          open_timeout: config.open_timeout,
          read_timeout: config.read_timeout,
          write_timeout: config.write_timeout
        }
      end

      def ssl_options
        {verify: config.ssl_verify}
      end

      def invoke_hook(hook, *args)
        hook&.call(*args)
      end
    end
  end
end

# frozen_string_literal: true

require "faraday"
require "json"

module OctaSpace
  module Transport
    # Standard HTTP transport built on Faraday
    #
    # - +Authorization: Bearer <api_key>+ per endpoint auth mode
    # - JSON request encoding and response parsing
    # - Retries with exponential backoff and jitter for GET and idempotent
    #   requests only, honouring Retry-After up to {Configuration#max_retry_after}
    # - Failover across several base URLs for GET requests on network errors;
    #   requests that change state are never sent to a second host
    # - on_request / on_response hooks, one log line per request
    # - Typed exceptions mapped from HTTP status codes
    #
    # @example
    #   config = OctaSpace::Configuration.new
    #   config.api_key = "octa_ak_..."
    #   transport = OctaSpace::Transport::FaradayTransport.new(config)
    #   transport.get("/accounts/balance").data
    class FaradayTransport < Base
      # Statuses worth retrying: rate limit and transient gateway/backend failures
      RETRY_STATUSES = [429, 502, 503, 504].freeze

      # @param config [OctaSpace::Configuration]
      # @param sleeper [#call] waits the given number of seconds between retries
      def initialize(config, sleeper: ->(seconds) { sleep(seconds) })
        @config = config
        @urls = config.urls.freeze
        raise ConfigurationError, "At least one base URL is required" if @urls.empty?

        @rotator = (@urls.size > 1) ? Middleware::UrlRotator.new(@urls) : nil
        @sleeper = sleeper
        @connections = {}
        @mutex = Mutex.new
        @rate_limit = nil
      end

      # (see Base#request)
      def request(method, path, params: {}, body: nil, auth: :required, idempotent: false)
        method = method.to_sym
        headers = build_headers(method, path, auth, body)
        retryable = method == :get || idempotent
        attempt = 0

        begin
          with_failover(method) do |url|
            perform(url, method, path, params: params, body: body, headers: headers, attempt: attempt)
          end
        rescue NetworkError, ApiError => e
          delay = (retryable && attempt < config.max_retries) ? retry_delay(e, attempt) : nil
          raise if delay.nil?

          @sleeper.call(delay) if delay.positive?
          attempt += 1
          retry
        end
      end

      # (see Base#rate_limit)
      def rate_limit = @mutex.synchronize { @rate_limit }

      # @return [Hash] transport diagnostics
      def transport_stats
        stats = {mode: :standard, urls: @urls}
        stats[:rotator] = @rotator.stats if @rotator
        stats
      end

      private

      attr_reader :config

      # GET requests try every URL in rotation order on network errors; other
      # methods go to a single URL so a request that changes state (and may
      # have reached the server before a timeout) is never sent twice.
      def with_failover(method)
        first = @rotator ? @rotator.next_url : @urls.first
        urls = (method == :get) ? [first, *(@urls - [first])] : [first]
        last_error = nil

        urls.each do |url|
          response = yield(url)
          @rotator&.mark_success(url)
          return response
        rescue NetworkError => e
          @rotator&.mark_failed(url)
          last_error = e
        end

        raise last_error
      end

      def perform(base_url, method, path, params:, body:, headers:, attempt:)
        query = params.to_h.compact
        invoke_hook(config.on_request,
          {method: method, url: "#{base_url}#{path}", path: path, params: query, attempt: attempt})

        started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        raw = begin
          execute(connection_for(base_url), method, path.delete_prefix("/"),
            query: query, payload: body.nil? ? nil : JSON.generate(body), headers: headers)
        rescue Faraday::TimeoutError => e
          log(method, base_url, path, "timeout", started)
          raise TimeoutError, "Request timed out: #{e.message}"
        rescue Faraday::ConnectionFailed, Faraday::SSLError => e
          log(method, base_url, path, "connection failed", started)
          raise ConnectionError, e.message
        end
        log(method, base_url, path, raw.status, started)

        response = build_response(raw)
        if (rate_limit = response.rate_limit)
          @mutex.synchronize { @rate_limit = rate_limit }
        end
        invoke_hook(config.on_response, response)
        raise OctaSpace.error_for(response, api_key: headers.key?("Authorization") ? config.api_key : nil) if response.error?

        response
      end

      # Overridden by PersistentTransport to run the request on a pooled connection
      def execute(conn, method, path, query:, payload:, headers:)
        conn.run_request(method, path, payload, headers) do |req|
          req.params.update(query) unless query.empty?
        end
      end

      def build_response(raw)
        text = raw.body.to_s
        data = nil
        unless text.strip.empty?
          begin
            data = JSON.parse(text)
          rescue JSON::ParserError
            # E.g. a proxy or captive portal answering 200 with an HTML page.
            if (200..299).cover?(raw.status)
              response = Response.new(status: raw.status, headers: raw.headers, body: text)
              raise ApiError.new("Response is not valid JSON (status #{raw.status})", response: response)
            end
          end
        end
        Response.new(status: raw.status, headers: raw.headers, body: text, data: data)
      end

      def build_headers(method, path, auth, body)
        headers = {"User-Agent" => config.user_agent, "Accept" => "application/json"}
        headers["Content-Type"] = "application/json" unless body.nil?

        unless auth == :none
          if config.api_key?
            headers["Authorization"] = "Bearer #{config.api_key}"
          elsif auth == :required
            raise AuthenticationError,
              "api_key is required for #{method.upcase} #{path}: pass an API key " \
              "(#{API_KEY_PREFIX}…) from Account → Credentials → API Keys in the OctaSpace dashboard"
          end
        end
        headers
      end

      # Seconds to wait before the next attempt, or nil when the error must be raised
      def retry_delay(error, attempt)
        return nil if error.is_a?(ApiError) && !RETRY_STATUSES.include?(error.status)

        retry_after = error.is_a?(ApiError) ? error.retry_after : nil
        return nil if retry_after && retry_after > config.max_retry_after
        return retry_after if retry_after

        cap = [config.max_retry_interval.to_f, config.retry_interval.to_f * (config.backoff_factor.to_f**attempt)].min
        rand * cap
      end

      def connection_for(base_url)
        @mutex.synchronize { @connections[base_url] ||= build_connection(base_url) }
      end

      def build_connection(base_url)
        Faraday.new(url: base_url, request: request_options, ssl: ssl_options) do |f|
          configure_adapter(f)
        end
      end

      # Override in PersistentTransport
      def configure_adapter(builder)
        builder.adapter :net_http
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

      def log(method, base_url, path, outcome, started)
        return unless config.logger

        ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000).round
        config.logger.public_send(config.log_level || :info,
          "[OctaSpace] #{method.upcase} #{base_url}#{path} -> #{outcome} (#{ms} ms)")
      end

      def invoke_hook(hook, *args)
        hook&.call(*args)
      end
    end
  end
end

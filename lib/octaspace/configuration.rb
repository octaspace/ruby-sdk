# frozen_string_literal: true

module OctaSpace
  # Default API base URL
  DEFAULT_BASE_URL = "https://api-dev.octa.space"

  # Prefix of account API keys (created in the OctaSpace dashboard under
  # Account → Credentials → API Keys)
  API_KEY_PREFIX = "octa_ak_"

  # Global and per-client configuration for the OctaSpace SDK
  #
  # @example Global configuration (Rails initializer)
  #   OctaSpace.configure do |config|
  #     config.api_key    = ENV["OCTA_API_KEY"]
  #     config.keep_alive = true
  #     config.pool_size  = ENV.fetch("RAILS_MAX_THREADS", 5).to_i
  #     config.logger     = Rails.logger
  #   end
  class Configuration
    # --- Authentication ---

    # Account API key (+octa_ak_…+), sent as +Authorization: Bearer <key>+.
    # Network and GPU statistics and the machine listings work without it. A
    # value that already starts with "Bearer " is accepted.
    # @return [String, nil]
    attr_reader :api_key

    # --- Connection ---

    # @return [String] Base URL of the API (one host)
    attr_accessor :base_url

    # Ordered list of API hosts. GET requests fail over to the next URL
    # on network errors; requests that change state are sent to one URL only.
    # Takes precedence over {#base_url}.
    # @return [Array<String>, nil]
    attr_accessor :base_urls

    # @return [Integer] Seconds to wait for connection to open
    attr_accessor :open_timeout

    # @return [Integer] Seconds to wait for a response
    attr_accessor :read_timeout

    # @return [Integer] Seconds to wait when writing request body
    attr_accessor :write_timeout

    # --- Keep-Alive / Persistent connections ---
    # Requires: gem "faraday-net_http_persistent" and gem "connection_pool"

    # @return [Boolean] Enable persistent HTTP connections with connection pooling
    attr_accessor :keep_alive

    # @return [Integer] Number of persistent connections in the pool
    attr_accessor :pool_size

    # @return [Integer] Seconds to wait for a connection from the pool
    attr_accessor :pool_timeout

    # @return [Integer] Seconds before an idle persistent connection is closed
    attr_accessor :idle_timeout

    # --- Retry ---
    # Only GET requests and the idempotent session stop are retried, on network
    # errors and on 429/502/503/504. Starting or restarting a service is never
    # retried: it costs money and is rate limited.

    # @return [Integer] Maximum number of retries on transient failures
    attr_accessor :max_retries

    # @return [Float] Base interval in seconds between retries
    attr_accessor :retry_interval

    # @return [Float] Exponential backoff multiplier
    attr_accessor :backoff_factor

    # @return [Float] Longest backoff delay in seconds (without Retry-After)
    attr_accessor :max_retry_interval

    # A Retry-After longer than this is raised to the caller instead of waited
    # for.
    # @return [Integer] seconds
    attr_accessor :max_retry_after

    # --- Hooks ---

    # @return [#call, nil] Callable invoked before each request attempt; receives
    #   a Hash with :method, :url, :path, :params and :attempt (never the headers,
    #   so the API key does not leak into logs)
    attr_accessor :on_request

    # @return [#call, nil] Callable invoked after each response; receives OctaSpace::Response
    attr_accessor :on_response

    # --- Logging ---

    # Logger for one line per request (method, URL, status, duration).
    # Headers and bodies are never logged: they carry the API key and,
    # for sessions, URLs that grant access.
    # @return [Logger, nil]
    attr_accessor :logger

    # @return [Symbol] Log level (:debug, :info, :warn, :error)
    attr_accessor :log_level

    # --- SSL ---

    # @return [Boolean] Verify the server's TLS certificate
    attr_accessor :ssl_verify

    # --- Identity ---

    # @return [String] User-Agent header value
    attr_accessor :user_agent

    DEFAULTS = {
      base_url: DEFAULT_BASE_URL,
      open_timeout: 10,
      read_timeout: 30,
      write_timeout: 30,
      keep_alive: false,
      pool_size: 5,
      pool_timeout: 5,
      idle_timeout: 60,
      max_retries: 2,
      retry_interval: 0.5,
      backoff_factor: 2.0,
      max_retry_interval: 10.0,
      max_retry_after: 60,
      ssl_verify: true,
      log_level: :info
    }.freeze

    def initialize
      DEFAULTS.each { |k, v| public_send(:"#{k}=", v) }
      @user_agent = "octaspace-ruby/#{OctaSpace::VERSION} Ruby/#{RUBY_VERSION}"
    end

    # Sets the API key; surrounding whitespace and a leading "Bearer " are
    # removed, and an empty value means no key.
    # @param value [String, nil]
    def api_key=(value)
      key = value.to_s.strip.sub(/\Abearer\s+/i, "")
      @api_key = key.empty? ? nil : key
    end

    # @return [Boolean] whether an API key is configured
    def api_key? = !api_key.nil?

    # @return [Boolean]
    def keep_alive? = !!keep_alive

    # Returns effective list of API URLs, without trailing slashes.
    # base_urls takes priority over base_url; always returns an Array.
    # @return [Array<String>]
    def urls
      candidates = clean_urls(base_urls)
      candidates.empty? ? clean_urls(base_url) : candidates
    end

    # Deep-clone configuration for per-client overrides
    # @return [Configuration]
    def dup
      copy = self.class.new
      instance_variables.each do |var|
        copy.instance_variable_set(var, instance_variable_get(var).dup)
      rescue TypeError
        copy.instance_variable_set(var, instance_variable_get(var))
      end
      copy
    end

    private

    def clean_urls(value)
      Array(value).map { |url| url.to_s.strip.sub(%r{/+\z}, "") }.reject(&:empty?)
    end
  end
end

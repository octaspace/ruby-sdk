# frozen_string_literal: true

module OctaSpace
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

    # @return [String, nil] API key for Authorization header
    attr_accessor :api_key

    # --- Connection ---

    # @return [String] Base URL for the API (single endpoint)
    attr_accessor :base_url

    # @return [Array<String>, nil] Multiple API endpoints — enables URL rotation/failover
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

    # @return [Integer] Maximum number of retries on transient failures
    attr_accessor :max_retries

    # @return [Float] Base interval in seconds between retries
    attr_accessor :retry_interval

    # @return [Float] Exponential backoff multiplier
    attr_accessor :backoff_factor

    # --- Hooks ---

    # @return [#call, nil] Callable invoked before each request; receives request context hash
    attr_accessor :on_request

    # @return [#call, nil] Callable invoked after each response; receives OctaSpace::Response
    attr_accessor :on_response

    # --- Logging ---

    # @return [Logger, nil] Ruby Logger instance (or any object responding to #debug/#info/#warn/#error)
    attr_accessor :logger

    # @return [Symbol] Log level (:debug, :info, :warn, :error)
    attr_accessor :log_level

    # --- SSL ---

    # @return [Boolean] Verify SSL certificates (set false only in development/test)
    attr_accessor :ssl_verify

    # --- Identity ---

    # @return [String] User-Agent header value
    attr_accessor :user_agent

    DEFAULTS = {
      base_url: "https://api.octa.space",
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
      ssl_verify: true,
      log_level: :info
    }.freeze

    def initialize
      DEFAULTS.each { |k, v| public_send(:"#{k}=", v) }
      @user_agent = "octaspace-ruby/#{OctaSpace::VERSION} Ruby/#{RUBY_VERSION}"
    end

    # Alias: `persistent` is the Cube-internal term; `keep_alive` is the public SDK term
    alias_method :persistent, :keep_alive
    alias_method :persistent=, :keep_alive=

    # @return [Boolean]
    def keep_alive? = !!keep_alive

    # Returns effective list of API URLs.
    # base_urls takes priority over base_url; always returns an Array.
    # @return [Array<String>]
    def urls
      candidates = Array(base_urls).map(&:to_s).reject(&:empty?)
      candidates.empty? ? Array(base_url).map(&:to_s).reject(&:empty?) : candidates
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
  end
end

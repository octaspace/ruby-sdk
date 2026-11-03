# frozen_string_literal: true

module OctaSpace
  # Main entry point for the OctaSpace SDK
  #
  # Aggregates all resource groups and constructs the appropriate
  # HTTP transport based on configuration.
  #
  # @example Standard mode (default)
  #   client = OctaSpace::Client.new(api_key: ENV["OCTA_API_KEY"])
  #   client.compute.list
  #   client.accounts.balance
  #
  # @example Keep-alive mode (persistent connections + pool)
  #   client = OctaSpace::Client.new(
  #     api_key:    ENV["OCTA_API_KEY"],
  #     keep_alive: true,
  #     pool_size:  ENV.fetch("RAILS_MAX_THREADS", 5).to_i
  #   )
  #
  # @example Multiple API endpoints with failover
  #   client = OctaSpace::Client.new(
  #     api_key:   ENV["OCTA_API_KEY"],
  #     base_urls: ["https://api-dev.octa.space", "https://mirror.example"]
  #   )
  #
  # @example Without API key (public endpoints only)
  #   client = OctaSpace::Client.new
  #   client.network.info
  #
  # @example With hooks
  #   client = OctaSpace::Client.new(
  #     api_key:     ENV["OCTA_API_KEY"],
  #     on_request:  ->(req)  { puts "→ #{req[:method].upcase} #{req[:path]}" },
  #     on_response: ->(resp) { puts "← #{resp.status}" }
  #   )
  class Client
    # @return [Resources::Accounts] balance
    attr_reader :accounts
    # @return [Resources::Compute] machines for rent: list, start, start_batch, restart
    attr_reader :compute
    # @return [Resources::Hosting] nodes of the account and their prices
    attr_reader :hosting
    # @return [Resources::Network] public platform statistics
    attr_reader :network
    # @return [Resources::Render] render nodes: list, start, start_batch
    attr_reader :render
    # @return [Resources::Sessions] running sessions: list, get, logs, stop, wait_ready, wait_stopped
    attr_reader :sessions
    # @return [Resources::Stats] public GPU market statistics
    attr_reader :stats

    # @param api_key [String, nil] API key for authentication (optional for public endpoints)
    # @param opts [Hash] Per-instance configuration overrides.
    #   Any attribute from OctaSpace::Configuration can be passed here.
    def initialize(api_key: nil, transport: nil, **opts)
      @config = build_config(api_key, opts)
      @transport = transport || build_transport
      @accounts = Resources::Accounts.new(@transport)
      @compute = Resources::Compute.new(@transport)
      @hosting = Resources::Hosting.new(@transport)
      @network = Resources::Network.new(@transport)
      @render = Resources::Render.new(@transport)
      @sessions = Resources::Sessions.new(@transport)
      @stats = Resources::Stats.new(@transport)
    end

    # Shut down persistent connections (only relevant in keep_alive mode)
    def shutdown
      @transport.respond_to?(:shutdown) && @transport.shutdown
    end

    # Transport diagnostics (pool stats when in keep_alive mode)
    # @return [Hash]
    def transport_stats
      @transport.respond_to?(:transport_stats) ? @transport.transport_stats : {mode: :custom}
    end

    # Rate limit state (RateLimit-* headers) of the most recent response that
    # carried them, or nil before the first such response.
    # @return [OctaSpace::RateLimit, nil]
    def rate_limit
      @transport.respond_to?(:rate_limit) ? @transport.rate_limit : nil
    end

    private

    # Merge global config with per-instance overrides
    def build_config(api_key, overrides)
      cfg = OctaSpace.configuration.dup
      cfg.api_key = api_key
      overrides.each do |key, value|
        cfg.public_send(:"#{key}=", value) if cfg.respond_to?(:"#{key}=")
      end
      cfg
    end

    def build_transport
      if @config.keep_alive?
        require_persistent_transport!
        Transport::PersistentTransport.new(@config)
      else
        Transport::FaradayTransport.new(@config)
      end
    end

    def require_persistent_transport!
      require "faraday/net_http_persistent"
      require "connection_pool"
      require "octaspace/transport/persistent_transport"
    rescue LoadError => e
      raise ConfigurationError,
        "keep_alive: true requires the following gems.\n" \
        "Add to your Gemfile:\n" \
        "  gem 'faraday-net_http_persistent'\n" \
        "  gem 'connection_pool'\n\n" \
        "Original error: #{e.message}"
    end
  end
end

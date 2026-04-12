# frozen_string_literal: true

module OctaSpace
  # Main entry point for the OctaSpace SDK
  #
  # Aggregates all resource groups and constructs the appropriate
  # HTTP transport based on configuration.
  #
  # @example Standard mode (default)
  #   client = OctaSpace::Client.new(api_key: ENV["OCTA_API_KEY"])
  #   client.nodes.list
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
  #     base_urls: ["https://api.octa.space", "https://api2.octa.space"]
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
    attr_reader :accounts, :nodes, :sessions, :apps,
      :network, :services, :idle_jobs

    # @param api_key [String, nil] API key for authentication (optional for public endpoints)
    # @param opts [Hash] Per-instance configuration overrides.
    #   Any attribute from OctaSpace::Configuration can be passed here.
    def initialize(api_key: nil, transport: nil, **opts)
      @config = build_config(api_key, opts)
      @transport = transport || build_transport
      @accounts = Resources::Accounts.new(@transport)
      @nodes = Resources::Nodes.new(@transport)
      @sessions = Resources::Sessions.new(@transport)
      @apps = Resources::Apps.new(@transport)
      @network = Resources::Network.new(@transport)
      @services = Resources::Services.new(@transport)
      @idle_jobs = Resources::IdleJobs.new(@transport)
    end

    # Shut down persistent connections (only relevant in keep_alive mode)
    def shutdown
      @transport.respond_to?(:shutdown) && @transport.shutdown
    end

    # Transport diagnostics (pool stats when in keep_alive mode)
    # @return [Hash]
    def transport_stats
      if @transport.respond_to?(:transport_stats)
        @transport.transport_stats
      elsif @transport.respond_to?(:pool_stats)
        {mode: :persistent, pools: @transport.pool_stats}
      elsif @config.urls.size > 1
        {mode: :standard, rotator: @transport.instance_variable_get(:@rotator)&.stats}
      else
        {mode: :standard, url: @config.urls.first}
      end
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

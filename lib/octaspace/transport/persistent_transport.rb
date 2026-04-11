# frozen_string_literal: true

module OctaSpace
  module Transport
    # Keep-alive HTTP transport using persistent connections and a connection pool
    #
    # Requires optional gems:
    #   gem "faraday-net_http_persistent"
    #   gem "connection_pool"
    #
    # Inherits all retry/failover/hook logic from FaradayTransport.
    # Overrides adapter configuration to use net_http_persistent with pooling.
    #
    # @example
    #   client = OctaSpace::Client.new(
    #     api_key:    "key",
    #     keep_alive: true,
    #     pool_size:  ENV.fetch("RAILS_MAX_THREADS", 5).to_i
    #   )
    class PersistentTransport < FaradayTransport
      def initialize(config)
        super
        @pools       = {}
        @pools_mutex = Mutex.new
      end

      # @return [Hash] connection pool diagnostics per URL
      def pool_stats
        @pools_mutex.synchronize do
          @pools.transform_values do |pool|
            {size: pool.size, available: pool.available}
          end
        end
      end

      # Shut down all connection pools gracefully
      def shutdown
        @pools_mutex.synchronize do
          @pools.each_value(&:shutdown)
          @pools.clear
        end
      end

      private

      # Override: return a ConnectionPool instead of a bare Faraday connection
      def build_connection(base_url)
        pool_for(base_url)
      end

      # Execute request via pool — `pool.with` yields a Faraday connection
      def execute(conn_or_pool, method, path, params: {}, body: nil, headers: {})
        if conn_or_pool.is_a?(::ConnectionPool)
          conn_or_pool.with { |conn| super(conn, method, path, params: params, body: body, headers: headers) }
        else
          super
        end
      end

      def pool_for(base_url)
        @pools_mutex.synchronize do
          @pools[base_url] ||= build_pool(base_url)
        end
      end

      def build_pool(base_url)
        pool_size    = config.pool_size
        pool_timeout = config.pool_timeout

        ::ConnectionPool.new(size: pool_size, timeout: pool_timeout) do
          build_persistent_connection(base_url)
        end
      end

      def build_persistent_connection(base_url)
        Faraday.new(url: base_url, request: request_options, ssl: ssl_options) do |f|
          f.request  :json
          f.request  :retry, retry_options
          f.response :json, content_type: /\bjson/
          f.response :logger, config.logger, {headers: true, bodies: false} if config.logger
          f.adapter  :net_http_persistent, pool_size: config.pool_size do |http|
            http.idle_timeout = config.idle_timeout
          end
        end
      end
    end
  end
end

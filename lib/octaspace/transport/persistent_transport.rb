# frozen_string_literal: true

module OctaSpace
  module Transport
    # Keep-alive HTTP transport using persistent connections and a connection pool
    #
    # Requires optional gems:
    #   gem "faraday-net_http_persistent"
    #   gem "connection_pool"
    #
    # Inherits all retry/failover/hook logic from FaradayTransport; each base
    # URL gets its own pool of persistent connections.
    #
    # @example
    #   client = OctaSpace::Client.new(
    #     api_key:    "octa_ak_...",
    #     keep_alive: true,
    #     pool_size:  ENV.fetch("RAILS_MAX_THREADS", 5).to_i
    #   )
    class PersistentTransport < FaradayTransport
      # @return [Hash] connection pool diagnostics per URL
      def pool_stats
        @mutex.synchronize do
          @connections.transform_values do |pool|
            {size: pool.size, available: pool.available}
          end
        end
      end

      # @return [Hash] transport diagnostics
      def transport_stats
        {mode: :persistent, urls: @urls, pools: pool_stats}
      end

      # Shut down all connection pools gracefully
      def shutdown
        @mutex.synchronize do
          @connections.each_value { |pool| pool.shutdown { |conn| conn.close if conn.respond_to?(:close) } }
          @connections.clear
        end
      end

      private

      # Override: a ConnectionPool of persistent Faraday connections
      def build_connection(base_url)
        ::ConnectionPool.new(size: config.pool_size, timeout: config.pool_timeout) do
          Faraday.new(url: base_url, request: request_options, ssl: ssl_options) do |f|
            f.adapter :net_http_persistent, pool_size: config.pool_size do |http|
              http.idle_timeout = config.idle_timeout
            end
          end
        end
      end

      # Run the request on a connection checked out of the pool
      def execute(pool, method, path, query:, payload:, headers:)
        pool.with { |conn| super(conn, method, path, query: query, payload: payload, headers: headers) }
      end
    end
  end
end

# frozen_string_literal: true

module OctaSpace
  module Resources
    # GPU market and mining statistics; no API key needed
    #
    # @example
    #   client.stats.gpu_current.gpus.first.rented_price.p50
    #   client.stats.gpu_history(gpu_name: "NVIDIA GeForce RTX 4090", from: Time.now - 7 * 86_400)
    #     .fetch("NVIDIA GeForce RTX 4090").points
    class Stats < Base
      # GPU models on the market now, most common first.
      # GET /stats/gpu/current
      # @param verified [String, Symbol, nil] "all" (default), "yes" or "no"
      # @return [OctaSpace::Types::GpuMarket]
      def gpu_current(verified: nil)
        Types::GpuMarket.new(get_public("/stats/gpu/current", verified: verified))
      end

      # GPU market over time, by model. Defaults to the last day with hourly
      # points. Invalid ranges (step < 300, too many points, from after to)
      # raise {OctaSpace::ValidationError}.
      # GET /stats/gpu/history
      #
      # @param gpu_name [String, Array<String>, nil] model name(s), or "all"
      # @param verified [String, Symbol, nil] "all", "yes" or "no"
      # @param from [Time, Integer, nil] range start (Unix seconds); the API's +start+
      # @param to [Time, Integer, nil] range end (Unix seconds); the API's +end+
      # @param step [Integer, nil] seconds between points, at least 300 (default 3600)
      # @return [Hash{String=>OctaSpace::Types::GpuHistory}] by model name
      def gpu_history(gpu_name: nil, verified: nil, from: nil, to: nil, step: nil)
        data = get_public("/stats/gpu/history",
          gpu_name: gpu_name.is_a?(Array) ? gpu_name.join(",") : gpu_name,
          verified: verified, start: unix(from), end: unix(to), step: step)
        data.to_h.transform_values { |history| Types::GpuHistory.wrap(history) }
      end

      # GPUs by city and model (GeoIP), without per-node detail.
      # GET /stats/gpu/locations
      # @return [Array<OctaSpace::Types::GpuLocation>]
      def gpu_locations
        Types::GpuLocation.wrap_all(get_public("/stats/gpu/locations"))
      end

      # What the platform's mining sessions run: miners, algorithms and pools,
      # most used first, and the miners per day.
      # GET /stats/mining
      #
      # @param role [String, Symbol, nil] "gpu" (default) or "cpu"
      # @param days [Integer, nil] days back, today included, 1..365 (default 30)
      # @return [OctaSpace::Types::MiningUsage]
      def mining(role: nil, days: nil)
        Types::MiningUsage.new(get_public("/stats/mining", role: role, days: days))
      end
    end
  end
end

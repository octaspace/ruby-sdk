# frozen_string_literal: true

module OctaSpace
  module Types
    # Price percentiles, micro-USD per GPU-hour; nil where there is no data
    class PricePercentiles < Model
      attribute :p10, :p25, :p50, :p75, :p90
    end

    # One GPU model on the market now
    class GpuMarketModel < Model
      # @!attribute [r] total
      #   @return [Integer] GPUs (not nodes) of this model
      # @!attribute [r] usage
      #   @return [Float] percent rented now
      # @!attribute [r] usage_30d
      #   @return [Float, nil] average percent rented over 30 days
      # @!attribute [r] memory_mb
      #   @return [Integer, nil] memory of one GPU, MiB: the size most GPUs of
      #     the model have
      attribute :model, :total, :available, :rented, :usage, :usage_30d, :memory_mb, :ai_score, :tflops, :tflops_per_dollar
      attribute :available_price, :rented_price, model: PricePercentiles
    end

    # GPU market now (+GET /stats/gpu/current+), most common models first
    class GpuMarket < Model
      # @!attribute [r] at
      #   @return [Integer] snapshot time, Unix seconds
      attribute :at
      attribute :gpus, model: GpuMarketModel, many: true

      # @return [Time, nil]
      def time = at.is_a?(Numeric) ? Time.at(at) : nil
    end

    # Parallel arrays of GPU counts
    class SupplyDemand < Model
      attribute :total, :available, :rented
    end

    # Parallel arrays of price percentiles
    class PriceSeries < Model
      attribute :p10, :p25, :p50, :p75, :p90
    end

    # One point of a model's history, see {GpuHistory#points}
    GpuHistoryPoint = Data.define(:ts, :total, :available, :rented, :available_price, :rented_price) do
      # @return [Time]
      def time = Time.at(ts)
    end

    # History of one GPU model (+GET /stats/gpu/history+): parallel arrays,
    # one value per entry of {#timestamps}
    class GpuHistory < Model
      # @!attribute [r] timestamps
      #   @return [Array<Integer>] Unix seconds
      attribute :timestamps, :tflops
      attribute :supply_demand, model: SupplyDemand
      attribute :available_price, :rented_price, model: PriceSeries

      # Turns the parallel arrays into one point per timestamp, e.g. for a chart.
      # @return [Array<GpuHistoryPoint>]
      def points
        Array(timestamps).each_with_index.map do |ts, i|
          GpuHistoryPoint.new(
            ts: ts,
            total: series_at(supply_demand, :total, i),
            available: series_at(supply_demand, :available, i),
            rented: series_at(supply_demand, :rented, i),
            available_price: percentiles_at(available_price, i),
            rented_price: percentiles_at(rented_price, i)
          )
        end
      end

      private

      def series_at(model, key, i) = model&.public_send(key)&.at(i)

      def percentiles_at(series, i)
        PricePercentiles.new(%w[p10 p25 p50 p75 p90].to_h { |p| [p, series_at(series, p, i)] })
      end
    end

    # GPUs of one model in one city (+GET /stats/gpu/locations+)
    class GpuLocation < Model
      # @!attribute [r] gpus
      #   @return [Integer] GPUs of this model in the city
      # @!attribute [r] verified
      #   @return [Integer] of them on verified nodes
      attribute :city, :country, :latitude, :longitude, :model, :gpus, :rented, :verified
    end

    # One miner, algorithm or pool of {MiningUsage}
    class MiningRow < Model
      # @!attribute [r] name
      #   @return [String] catalogue name, or "other"
      # @!attribute [r] started
      #   @return [Integer] sessions that started (or restarted) with it
      # @!attribute [r] gpu_hours
      #   @return [Float] hours times GPUs; 0 for the CPU role
      # @!attribute [r] coins
      #   @return [Array<String>, nil] pools only
      attribute :name, :label, :started, :hours, :gpu_hours, :coins
    end

    # Totals of {MiningUsage}
    class MiningTotal < Model
      attribute :started, :hours, :gpu_hours
    end

    # Miners per day of {MiningUsage}
    class MiningDaily < Model
      # @!attribute [r] dates
      #   @return [Array<String>] ISO dates
      # @!attribute [r] miners
      #   @return [Hash{String=>Array<Float>}] one value of {MiningUsage#measure}
      #     per date, by miner name
      attribute :dates, :miners
    end

    # What the platform's mining sessions run (+GET /stats/mining+), most used first
    class MiningUsage < Model
      # @!attribute [r] role
      #   @return [String] "gpu" or "cpu"
      # @!attribute [r] from
      #   @return [String] first day, ISO date
      # @!attribute [r] to
      #   @return [String] last day, ISO date
      # @!attribute [r] measure
      #   @return [String] "gpu_hours" or "hours"
      # @!attribute [r] at
      #   @return [Integer, nil] snapshot time, Unix seconds
      attribute :role, :days, :from, :to, :measure, :at
      attribute :total, model: MiningTotal
      attribute :miners, :algorithms, :pools, model: MiningRow, many: true
      attribute :daily, model: MiningDaily

      # @return [Time, nil]
      def time = at.is_a?(Numeric) ? Time.at(at) : nil
    end
  end
end

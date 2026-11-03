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
      attribute :model, :total, :available, :rented, :usage, :usage_30d, :ai_score, :tflops, :tflops_per_dollar
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
  end
end

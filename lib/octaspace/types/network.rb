# frozen_string_literal: true

module OctaSpace
  module Types
    # Platform statistics snapshot (+GET /network+), refreshed every few minutes
    class Network < Model
      # Node counts
      class Nodes < Model
        attribute :online, :available, :rented, :countries
      end

      # Total hardware of online nodes; +memory+ and +disk+ in bytes
      class Power < Model
        # @!attribute [r] gpus_rented
        #   @return [Integer, nil] GPUs in running sessions
        attribute :cpu_cores, :disk, :gpus, :gpus_rented, :memory, :tflops
      end

      # Rendered frames of one week
      class WeekFrames < Model
        attribute :week, :frames
      end

      # Render farm counters
      class Render < Model
        attribute :frames_24h, :frames_total
        attribute :frames_by_week, model: WeekFrames, many: true
      end

      # Session counters
      class Sessions < Model
        attribute :running, :total, :last_24h
      end

      # User counters
      class Users < Model
        attribute :total, :last_24h
      end

      # VPN node counters
      class Vpn < Model
        attribute :nodes, :countries
      end

      # @!attribute [r] at
      #   @return [Integer] snapshot time, Unix seconds; see {#time}
      attribute :at
      attribute :nodes, model: Nodes
      attribute :power, model: Power
      attribute :render, model: Render
      attribute :sessions, model: Sessions
      attribute :users, model: Users
      attribute :vpn, model: Vpn

      # @return [Time, nil]
      def time = at.is_a?(Numeric) ? Time.at(at) : nil
    end

    # Fields of {NetworkHistory} and {NetworkHistoryPoint}, besides the timestamp
    NETWORK_HISTORY_FIELDS = %i[nodes_online nodes_available nodes_rented countries gpus gpus_rented
      tflops vpn_nodes users sessions_running sessions_24h].freeze

    # One point of the network history, see {NetworkHistory#points}. Values
    # are averages over the step (so they can be fractional), nil without data.
    NetworkHistoryPoint = Data.define(:ts, *NETWORK_HISTORY_FIELDS) do
      # @return [Time]
      def time = Time.at(ts)
    end

    # Platform statistics over time (+GET /network/history+): parallel arrays,
    # one value per entry of {#timestamps}
    class NetworkHistory < Model
      # @!attribute [r] timestamps
      #   @return [Array<Integer>] start of each step, Unix seconds; steps
      #     without data are left out
      attribute :timestamps, *NETWORK_HISTORY_FIELDS

      # Turns the parallel arrays into one point per timestamp, e.g. for a chart.
      # @return [Array<NetworkHistoryPoint>]
      def points
        Array(timestamps).each_with_index.map do |ts, i|
          NetworkHistoryPoint.new(ts: ts, **NETWORK_HISTORY_FIELDS.to_h { |field| [field, Array(self[field])[i]] })
        end
      end
    end
  end
end

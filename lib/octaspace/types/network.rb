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
        attribute :cpu_cores, :disk, :gpus, :memory, :tflops
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
  end
end

# frozen_string_literal: true

require "time"

module OctaSpace
  module Types
    # Prices of a hosted node, integer micro-USD
    class NodePrices < Model
      # @!attribute [r] base
      #   @return [Integer] per hour
      # @!attribute [r] storage
      #   @return [Integer] per GB of disk per hour
      # @!attribute [r] traffic
      #   @return [Integer] per GB of traffic
      # @!attribute [r] min_rent_minutes
      #   @return [Integer] minimum rent, 0..60 (0 = none)
      attribute :base, :storage, :traffic, :min_rent_minutes
    end

    # Whether a node is offered for a service, and why not
    class ServiceOffer < Model
      # @!attribute [r] reason
      #   @return [String, nil] e.g. "ports_closed"
      attribute :offered, :reason

      def offered? = offered == true
    end

    # A verification or benchmark that is running on a node
    class NodeActivity < Model
      # @!attribute [r] kind
      #   @return [String] "verification" or "benchmark"
      # @!attribute [r] started_at
      #   @return [Integer, nil] Unix seconds
      attribute :kind, :step, :started_at

      # @return [Time, nil]
      def started_time = started_at.is_a?(Numeric) ? Time.at(started_at) : nil
    end

    # Size and use of memory or disk, bytes
    class ResourceUsage < Model
      attribute :size, :free, :used, :used_percent
    end

    # A GPU as the node reports it; fields beyond these via #[]
    class HostingGpu < Gpu
      attribute :mem_free_mb, :fan_speed, :gpu_temperature, :gpu_utilization, :power_draw_watt, :pstate
    end

    # Hardware and OS of a hosted node
    class HostingSystem < Model
      attribute :cpu_cores, :cpu_model_name, :cpu_load_percent, :os_version
      attribute :memory, :disk, model: ResourceUsage
      attribute :gpus, model: HostingGpu, many: true
    end

    # Location of a node (GeoIP)
    class Location < Model
      attribute :city, :country, :latitude, :longitude
    end

    # An online node of the account (+GET /hosting/nodes+)
    class HostingNode < Model
      # @!attribute [r] number
      #   @return [String] node number, e.g. "M95S-WZG8-7" (the one renters see)
      # @!attribute [r] status
      #   @return [String] "idle", "rented", "verification", "benchmark" or "unknown"
      # @!attribute [r] verified
      #   @return [Boolean, nil] passed verification; nil while unknown
      # @!attribute [r] osn
      #   @return [String] node software version
      # @!attribute [r] online_at
      #   @return [String] ISO 8601; see {#online_time}
      # @!attribute [r] uptime
      #   @return [Integer] seconds since the machine booted
      # @!attribute [r] uptime_percent
      #   @return [Float] online over the last 30 days (97 and above show as 100)
      attribute :number, :status, :maintenance, :verified, :ip, :osn, :online_at, :uptime, :uptime_percent
      attribute :activity, model: NodeActivity
      attribute :prices, model: NodePrices
      attribute :system, model: HostingSystem
      attribute :location, model: Location

      def maintenance? = maintenance == true
      def verified? = verified == true
      def idle? = status == "idle"
      def rented? = status == "rented"

      # @return [Hash{String=>ServiceOffer}] by service ("compute", "render", …)
      def services
        @services ||= self["services"].to_h.transform_values { |offer| ServiceOffer.wrap(offer) }
      end

      # @param service [String, Symbol]
      # @return [Boolean] whether the node is offered for this service
      def offered?(service) = services[service.to_s]&.offered? || false

      # @return [Time, nil]
      def online_time
        online_at.is_a?(String) ? Time.iso8601(online_at) : nil
      rescue ArgumentError
        nil
      end
    end
  end
end

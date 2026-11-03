# frozen_string_literal: true

module OctaSpace
  module Types
    # A GPU of a machine listing (+GpuNvidia+ in the API spec)
    class Gpu < Model
      # @!attribute [r] model
      #   @return [String] GPU model name
      # @!attribute [r] mem_total_mb
      #   @return [Integer] total memory, MB
      # @!attribute [r] core_clock
      #   @return [Integer, nil] core clock ceiling, MHz
      # @!attribute [r] mem_clock
      #   @return [Integer, nil] memory clock ceiling, MHz
      # @!attribute [r] power_limit
      #   @return [Integer, nil] power limit, W; nil if the card reports none
      # @!attribute [r] tuned
      #   @return [Boolean] the node owner changed the card's power limit or clocks
      attribute :model, :mem_total_mb, :pcie_link_gen, :pcie_link_width,
        :core_clock, :mem_clock, :power_limit, :tuned

      def tuned? = tuned == true
    end

    # Node reliability (an open object in the API). {#uptime} is the percent of
    # time online over the last 30 days; other keys via {#[]}.
    class Reliability < Model
      attribute :uptime, :stability, :s_normal, :s_failed, :s_avg_d, :s_max_d
    end

    # Fields shared by compute and render listings
    class Machine < Model
      # @!attribute [r] node_number
      #   @return [String] node number, e.g. "7KQ4-M2XD-4"
      # @!attribute [r] base_price
      #   @return [Integer] price per hour, micro-USD
      # @!attribute [r] min_rent_minutes
      #   @return [Integer] minimum rent, minutes (0 = none); a session stopped
      #     sooner is charged for that long
      # @!attribute [r] memory
      #   @return [Integer] free memory, bytes
      # @!attribute [r] disk
      #   @return [Integer] free disk, bytes
      # @!attribute [r] net_down_mbps
      #   @return [Integer] download speed, Mbit/s; 0 if not measured
      # @!attribute [r] net_up_mbps
      #   @return [Integer] upload speed, Mbit/s; 0 if not measured
      attribute :node_number, :base_price, :min_rent_minutes,
        :blender_score, :city, :country, :cpu_cores, :cpu_model_name, :cuda_version,
        :disk, :memory, :gpu_vendor, :net_down_mbps, :net_up_mbps
      attribute :gpus, model: Gpu, many: true
      attribute :reliability, model: Reliability
    end

    # A machine available for rent (+GET /services/compute+)
    class ComputeMachine < Machine
      # @!attribute [r] storage_price
      #   @return [Integer] price per GB of disk per hour, micro-USD
      # @!attribute [r] traffic_price
      #   @return [Integer] price per GB of traffic, micro-USD
      # @!attribute [r] disk_type
      #   @return [String, nil] "nvme", "ssd", "hdd" or nil if unknown
      attribute :storage_price, :traffic_price, :arch, :ai_score,
        :disk_type, :disk_speed_mbs, :memory_speed, :memory_type, :free_ports
    end

    # A node available for render (+GET /services/render+); billed by the hour only
    class RenderMachine < Machine
    end

    # Outcome of one item of a batch start
    class BatchResult < Model
      # @!attribute [r] id
      #   @return [Integer, String] the client-side id of the request item
      # @!attribute [r] status
      #   @return [Integer] 0 = started, 1 = failed
      # @!attribute [r] uuid
      #   @return [String, nil] session uuid when started
      # @!attribute [r] reason
      #   @return [String, nil] why the item failed
      attribute :id, :status, :uuid, :reason

      def started? = status == 0
      def failed? = !started?
    end
  end
end

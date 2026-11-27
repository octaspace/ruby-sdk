# frozen_string_literal: true

module OctaSpace
  module Types
    # A GPU of a machine listing
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

    # Node reliability. {#uptime} is the percent of time online over the last
    # 30 days; other keys via {#[]}.
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
      # @!attribute [r] country_iso
      #   @return [String, nil] ISO 3166-1 alpha-2 country code, e.g. "DE"
      # @!attribute [r] os_version
      #   @return [String, nil] operating system of the node, e.g. "Ubuntu 24.04"
      # @!attribute [r] virt
      #   @return [String, nil] virtualization the node runs in; "none" on bare metal
      attribute :storage_price, :traffic_price, :arch, :ai_score,
        :disk_type, :disk_speed_mbs, :memory_speed, :memory_type, :free_ports,
        :country_iso, :os_version, :virt, :is_wsl, :is_hive_os, :gpu_pt

      # @return [Boolean] the node runs in WSL
      def wsl? = is_wsl == true

      # @return [Boolean] the node runs HiveOS
      def hive_os? = is_hive_os == true

      # @return [Boolean] GPU passthrough is available
      def gpu_passthrough? = gpu_pt == true
    end

    # A node available for render (+GET /services/render+); billed by the hour only
    class RenderMachine < Machine
    end

    # A node offered for VPN (+GET /services/vpn+); billed by traffic only
    class VpnMachine < Model
      # @!attribute [r] node_number
      #   @return [String] node number, e.g. "7KQ4-M2XD-4"
      # @!attribute [r] traffic_price
      #   @return [Integer] price per GB of traffic, micro-USD
      # @!attribute [r] protocols
      #   @return [Array<String>] protocols that passed the connection check on
      #     this node (at least one): "wg", "awg", "reality", "http_proxy"
      # @!attribute [r] residential
      #   @return [Boolean] the node's address is believed to belong to a residence
      # @!attribute [r] net_down_mbps
      #   @return [Integer] download speed, Mbit/s; 0 if not measured
      attribute :node_number, :traffic_price, :protocols, :city, :country, :country_iso,
        :latitude, :longitude, :residential, :net_down_mbps, :net_up_mbps

      def residential? = residential == true

      # @param protocol [String, Symbol] e.g. :wg
      # @return [Boolean] whether a session with this +subkind+ can be started here
      def supports?(protocol) = Array(protocols).include?(protocol.to_s)
    end

    # An app to start a compute session from (+GET /compute/apps+)
    class ComputeApp < Model
      # Logo and disk recommendation of an app
      class Extra < Model
        # @!attribute [r] min_disk_size
        #   @return [Integer, nil] disk the app needs, GB; a recommendation only
        attribute :logo, :min_disk_size
      end

      # @!attribute [r] uuid
      #   @return [String] pass as +app:+ to +compute.start+
      # @!attribute [r] image
      #   @return [String] container image, e.g. "ubuntu:24.04"; pass as +image:+
      # @!attribute [r] personal
      #   @return [Boolean] one of your own apps, not an official one
      # @!attribute [r] startup_script
      #   @return [String, nil] your own apps only
      # @!attribute [r] envs
      #   @return [Hash{String=>String}, nil] your own apps only
      attribute :uuid, :name, :image, :personal, :category, :description,
        :entrypoint, :ports, :http_ports, :startup_script, :envs
      attribute :extra, model: Extra

      def personal? = personal == true

      # @return [Integer, nil] see {Extra#min_disk_size}
      def min_disk_size = extra&.min_disk_size

      # @return [String, nil] logo URL
      def logo = extra&.logo
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

# frozen_string_literal: true

module OctaSpace
  module Types
    # Converts Unix milliseconds to Time
    # @api private
    def self.time_ms(value) = value.is_a?(Numeric) ? Time.at(value / 1000.0) : nil

    # An SSH endpoint of a session
    #
    # +user+ comes from the image's USER, so the image author controls it.
    # Before running +ssh+ with these values, check them and pass them as
    # separate arguments after "--" (+ssh -p PORT -l USER -- HOST+), so a
    # value like "-oProxyCommand=…" cannot run a local command.
    class SshEndpoint < Model
      attribute :host, :port, :user
    end

    # SSH access of a compute session
    class SessionSsh < Model
      # @!attribute [r] direct
      #   @return [SshEndpoint, nil] direct access; only when the account has an SSH key
      # @!attribute [r] proxy
      #   @return [SshEndpoint, nil] access through the platform's SSH proxy
      # @!attribute [r] web
      #   @return [String, nil] web terminal URL. It contains credentials:
      #     do not log it.
      attribute :direct, :proxy, model: SshEndpoint
      attribute :web
      redact :web

      # @return [SshEndpoint, nil] direct access when available, otherwise the proxy
      def endpoint = direct || proxy
    end

    # Hardware of the node a session runs on, as recorded at its start
    class NodeHw < Model
      # @!attribute [r] total_memory
      #   @return [Integer] bytes
      # @!attribute [r] disk
      #   @return [Integer] rented disk, GB
      # @!attribute [r] net_down_mbps
      #   @return [Integer, nil] Mbit/s; nil for sessions started before the API reported it
      attribute :cpu, :cpu_cores, :total_memory, :memory_speed, :memory_type,
        :disk, :disk_type, :disk_speed_mbs, :gpu_vendor, :net_down_mbps, :net_up_mbps
      attribute :gpus, model: Gpu, many: true
    end

    # A running session (+GET /sessions+, +GET /services/{uuid}/info+).
    #
    # {.build} returns a {ComputeSession} or a {RenderSession} by the +service+
    # field, and a plain Session for a service this SDK does not know yet.
    # Many fields are nil while the session is starting.
    class Session < Model
      # @!attribute [r] service
      #   @return [String] "compute", "render", or a service added later
      # @!attribute [r] status
      #   @return [String] "starting" or "ready"
      # @!attribute [r] progress
      #   @return [String, nil] current configuration step
      # @!attribute [r] pull_percent
      #   @return [Integer, nil] image pull progress, 0..100 (an estimate)
      # @!attribute [r] duration
      #   @return [Integer] seconds since the start
      # @!attribute [r] started_at
      #   @return [Integer, nil] Unix milliseconds; see {#started_time}
      # @!attribute [r] base_price
      #   @return [Integer, nil] price per hour fixed at the start, micro-USD
      # @!attribute [r] charge_amount
      #   @return [Integer, nil] charged so far, micro-USD
      attribute :service, :uuid, :status, :progress, :pull_percent, :duration, :started_at,
        :node_number, :base_price, :charge_amount, :app_name, :app_logo
      attribute :node_hw, model: NodeHw

      # @param data [Hash] a session JSON object
      # @return [Session] the subclass matching +service+
      def self.build(data)
        return data unless data.is_a?(Hash)

        klass = case data["service"]
        when "compute" then ComputeSession
        when "render" then RenderSession
        else Session
        end
        klass.new(data)
      end

      def ready? = status == "ready"
      def starting? = status == "starting"
      def compute? = service == "compute"
      def render? = service == "render"

      # @return [Time, nil] {#started_at} as a Time
      def started_time = Types.time_ms(started_at)
    end

    # A running compute session
    class ComputeSession < Session
      # @!attribute [r] ports
      #   @return [Hash{String=>Integer}] container port => public port
      # @!attribute [r] urls
      #   @return [Hash{String=>String}] HTTP port => URL
      # @!attribute [r] fm
      #   @return [String, nil] web file manager URL; it needs no login, so treat it as a secret
      # @!attribute [r] envs
      #   @return [Hash{String=>String}] environment variables of the container
      # @!attribute [r] rx
      #   @return [Integer] bytes received
      # @!attribute [r] tx
      #   @return [Integer] bytes sent
      attribute :public_ip, :city, :country, :country_iso, :ports, :urls, :fm, :envs,
        :rx, :tx, :storage_price, :traffic_price, :min_rent_minutes
      attribute :ssh, model: SessionSsh
      redact :fm
    end

    # A running render session; billed by the hour until stopped
    class RenderSession < Session
    end

    # A platform event of a session's system log
    class LogEntry < Model
      # @!attribute [r] msg
      #   @return [String] may span several lines
      # @!attribute [r] ts
      #   @return [Integer, nil] Unix milliseconds; see {#time}
      attribute :msg, :ts

      # @return [Time, nil]
      def time = Types.time_ms(ts)
    end

    # Logs of a running compute session (+GET /services/{uuid}/logs+)
    class SessionLogs < Model
      # @!attribute [r] system
      #   @return [Array<LogEntry>] platform events, oldest first
      # @!attribute [r] container
      #   @return [String, nil] the latest container output (up to 1 MiB, may
      #     contain "\r\n"); nil while the node does not report it
      # @!attribute [r] container_truncated
      #   @return [Boolean] the output was cut to its last 1 MiB
      attribute :system, model: LogEntry, many: true
      attribute :container, :container_truncated

      def container_truncated? = container_truncated == true
    end
  end
end

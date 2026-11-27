# frozen_string_literal: true

module OctaSpace
  module Resources
    # Compute machines and apps: listing, start (single and batch) and restart.
    #
    # @example
    #   machine = client.compute.list.min_by(&:base_price)
    #   uuid = client.compute.start(node_number: machine.node_number, image: "ubuntu:24.04",
    #                               disk_size: 10, ssh: true)
    #   client.sessions.wait_ready(uuid)
    class Compute < Base
      # Parameters that {#restart} replaces
      RESTART_PARAMS = %i[disk_size envs ports http_ports entrypoint args ssh fm startup_script].freeze

      # Parameters of {#start}
      START_PARAMS = (%i[node_number image app] + RESTART_PARAMS).freeze

      # Machines available for rent.
      # GET /services/compute
      #
      # Works without an API key, but is then refreshed about once an hour;
      # with a key it is at most 10 seconds old.
      # @return [Array<OctaSpace::Types::ComputeMachine>]
      def list
        Types::ComputeMachine.wrap_all(normalize_machines(get("/services/compute", auth: :optional).data))
      end

      # Apps to start a session from: the official ones and, with an API key,
      # your own (+personal?+), which also carry +startup_script+ and +envs+.
      # GET /compute/apps
      #
      # @example Start a session from an app
      #   app = client.compute.apps.find { |a| a.name == "Ubuntu 24.04 LTS" }
      #   client.compute.start(node_number: "7KQ4-M2XD-4", image: app.image, app: app.uuid,
      #                        disk_size: [app.min_disk_size || 1, 10].max)
      # @return [Array<OctaSpace::Types::ComputeApp>]
      def apps
        data = Array(get("/compute/apps", auth: :optional).data)
        data.each do |app|
          next unless app.is_a?(Hash)

          %w[category description].each { |field| app[field] = nil if app[field] == "null" }
        end
        Types::ComputeApp.wrap_all(data)
      end

      # Starts one session.
      # POST /services/compute
      #
      # Returns as soon as the session is created; wait for it with
      # +client.sessions.wait_ready+. Validation and business errors
      # ("Insufficient balance", "Node not available", …) raise
      # {OctaSpace::ValidationError}; an unknown parameter raises ArgumentError
      # before anything is sent. Never retried automatically: a start costs
      # money.
      #
      # @param node_number [String] node number from the listing, e.g. "7KQ4-M2XD-4"
      #   (case, dashes and spaces are ignored)
      # @param image [String] container image, e.g. "ubuntu:24.04"
      # @param app [String, nil] uuid of an app from {#apps}; +image+ is still required
      # @param disk_size [Integer, nil] disk, GB (default 1); an app's +min_disk_size+
      #   is a recommendation: with less, the app may run out of space
      # @param envs [Hash{String=>String}, nil] up to 64 variables, values up to 4 KiB
      # @param ports [Array<Integer>, nil] TCP/UDP ports to expose (0 and 22 are ignored)
      # @param http_ports [Array<Integer>, nil] HTTP ports to expose (7681, 7682 are reserved)
      # @param entrypoint [String, nil] replaces the image's ENTRYPOINT (one line, up to 4 KiB)
      # @param args [String, nil] replaces the image's CMD (one line, up to 4 KiB)
      # @param ssh [Boolean, nil] web terminal and SSH access; nil = the app's setting
      # @param fm [Boolean, nil] web file manager (no login: anyone with the URL can use it);
      #   nil = the app's setting
      # @param startup_script [String, nil] run as root in the background once the container is up
      # @return [String] the session uuid
      def start(**params)
        missing = %i[node_number image].reject { |key| params.key?(key) }
        raise ArgumentError, "missing keyword(s): #{missing.join(", ")}" if missing.any?

        post("/services/compute", body: compact_params(params, START_PARAMS)).data.fetch("uuid")
      end

      # Starts several sessions at once.
      # POST /services/compute
      #
      # Each item is validated on its own and reported in request order; a
      # failed item does not fail the batch. Items without an +:id+ get their
      # position in the array; ids may be integers or strings.
      #
      # @param items [Array<Hash>] {#start} parameters, each with an optional +:id+
      # @return [Array<OctaSpace::Types::BatchResult>]
      def start_batch(items)
        Types::BatchResult.wrap_all(post("/services/compute", body: batch_items(items, START_PARAMS)).data)
      end

      # Recreates the session's container on the same node, keeping the rent,
      # uuid and prices.
      # POST /services/compute/{uuid}/restart
      #
      # Follow the progress with +client.sessions.get(uuid)+; if the new
      # parameters cannot be applied, the session stops.
      #
      # - Without parameters: restarts with the original parameters.
      # - With parameters: *replaces all of them*. Every omitted parameter gets
      #   a fixed default, not its current value: +disk_size+ 1 GB,
      #   +entrypoint+/+args+ from the image, no +startup_script+, no +envs+,
      #   no +ports+/+http_ports+, +ssh+/+fm+ from the app (off without one).
      #   Pass the full set you want, +disk_size+ included.
      #
      # Raises {OctaSpace::ConflictError} (409) while the session is still
      # starting or restarting, and {OctaSpace::RateLimitError} (429) when it is
      # restarted more often than once per 5 minutes or 6 times per hour
      # (+retry_after+ says how long to wait). Never retried automatically.
      #
      # @param uuid [String]
      # @param params [Hash] see {#start}, without node_number, image and app
      # @return [String] the session uuid
      def restart(uuid, **params)
        body = compact_params(params, RESTART_PARAMS)
        response = post("/services/compute/#{encode(uuid)}/restart", body: body.empty? ? nil : body)
        response.data.is_a?(Hash) ? response.data.fetch("uuid", uuid) : uuid
      end
    end
  end
end

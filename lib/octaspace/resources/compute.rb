# frozen_string_literal: true

module OctaSpace
  module Resources
    # Compute machines: listing, start (single and batch) and restart.
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
      # Works without an API key, but the anonymous listing is cached for up
      # to an hour; with a key it is at most 10 seconds old.
      # @return [Array<OctaSpace::Types::ComputeMachine>]
      def list
        Types::ComputeMachine.wrap_all(normalize_machines(get("/services/compute", auth: :optional).data))
      end

      # Starts one session.
      # POST /services/compute (object → 201)
      #
      # Validation and business errors ("Insufficient balance", "Node not
      # available", …) raise {OctaSpace::ValidationError}. Never retried
      # automatically: a start costs money.
      #
      # @param node_number [String] node number from the listing, e.g. "7KQ4-M2XD-4"
      #   (case, dashes and spaces are ignored by the API)
      # @param image [String] container image, e.g. "ubuntu:24.04"
      # @param app [String, nil] application uuid
      # @param disk_size [Integer, nil] disk, GB (API default 1)
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
      # POST /services/compute (array → 200)
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
      # POST /services/compute/{uuid}/restart (→ 202)
      #
      # Follow the progress with +client.sessions.get(uuid)+; if the new
      # parameters cannot be applied, the session stops.
      #
      # - Without parameters: restarts with the original parameters.
      # - With parameters: *replaces all of them*. Every omitted parameter gets
      #   a fixed default, not its current value: +disk_size+ 1 GB,
      #   +entrypoint+/+args+ from the image, no +startup_script+, no +envs+,
      #   no +ports+/+http_ports+, +ssh+/+fm+ from the app (off without one).
      #   The API does not report a session's launch parameters, so pass the
      #   full set you want, +disk_size+ included.
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

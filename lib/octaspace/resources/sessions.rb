# frozen_string_literal: true

module OctaSpace
  module Resources
    # The account's running sessions.
    #
    # The API reports running sessions only: once a session stops, {#get},
    # {#logs} and {#stop} raise {OctaSpace::NotFoundError}, and there is no
    # session history.
    #
    # @example
    #   uuid = client.compute.start(node_number: "M95S-WZG8-7", image: "ubuntu:24.04")
    #   session = client.sessions.wait_ready(uuid) { |s| puts "#{s.progress} #{s.pull_percent}" }
    #   client.sessions.logs(uuid, tail: 50).container
    #   client.sessions.stop(uuid)
    #   client.sessions.wait_stopped(uuid)
    class Sessions < Base
      # Default seconds between polls of {#wait_ready} and {#wait_stopped}
      # (the authenticated limit is 300 requests a minute per account)
      DEFAULT_WAIT_INTERVAL = 3

      # @param sleeper [#call] waits the given number of seconds between polls
      def initialize(transport, sleeper: ->(seconds) { sleep(seconds) })
        super(transport)
        @sleeper = sleeper
      end

      # Running sessions of the account, oldest first.
      # GET /sessions
      # @return [Array<OctaSpace::Types::Session>] ComputeSession / RenderSession,
      #   or a plain Session for a service this SDK does not know
      def list
        Array(get_raw("/sessions").data).map { |item| Types::Session.build(item) }
      end

      # A running session.
      # GET /services/{uuid}/info
      #
      # Raises {OctaSpace::NotFoundError} when it has stopped or never existed,
      # and {OctaSpace::ValidationError} for a malformed uuid.
      # @param uuid [String]
      # @return [OctaSpace::Types::Session]
      def get(uuid)
        Types::Session.build(get_raw(session_path(uuid, "info")).data)
      end

      # System log and latest container output of a running compute session.
      # GET /services/{uuid}/logs
      #
      # Render sessions have no logs; a stopped session's logs are gone (404).
      # @param uuid [String]
      # @param tail [Integer, nil] last lines of container output, 1..1000 (API default 200)
      # @return [OctaSpace::Types::SessionLogs]
      def logs(uuid, tail: nil)
        Types::SessionLogs.new(get_raw(session_path(uuid, "logs"), params: {tail: tail}).data)
      end

      # Stops a session.
      # POST /services/{uuid}/stop (→ 202)
      #
      # Stopping is asynchronous: the session is gone once {#get} raises
      # NotFoundError (see {#wait_stopped}). Repeating the call while the
      # session is stopping is harmless, so it is retried on transient errors.
      # A session stopped before its +min_rent_minutes+ is charged base and
      # storage for that long.
      # @param uuid [String]
      # @return [String] the session uuid
      def stop(uuid)
        response = post(session_path(uuid, "stop"), idempotent: true)
        response.data.is_a?(Hash) ? response.data.fetch("uuid", uuid) : uuid
      end

      # Polls the session until its status is "ready" and returns it.
      #
      # After +compute.restart+ the session may still report "ready" for a
      # moment: wait until it leaves "ready" first if you need to observe the
      # restart finishing.
      #
      # @param uuid [String]
      # @param timeout [Numeric, nil] seconds; nil waits indefinitely
      # @param interval [Numeric] seconds between polls
      # @yieldparam session [OctaSpace::Types::Session] every polled state (progress reporting)
      # @return [OctaSpace::Types::Session]
      # @raise [OctaSpace::SessionStoppedError] the session stopped meanwhile
      # @raise [OctaSpace::WaitTimeoutError] the timeout ran out
      def wait_ready(uuid, timeout: nil, interval: DEFAULT_WAIT_INTERVAL)
        poll(timeout, interval) do
          session = begin
            get(uuid)
          rescue NotFoundError => e
            raise SessionStoppedError.new("Session #{uuid} stopped before it became ready: #{e.message}", response: e.response)
          end
          yield session if block_given?
          session if session.ready?
        end
      end

      # Polls until the API no longer reports the session (404), i.e. it has
      # stopped. Returns at once for a session that is already gone.
      #
      # @param uuid [String]
      # @param timeout [Numeric, nil] seconds; nil waits indefinitely
      # @param interval [Numeric] seconds between polls
      # @return [true]
      # @raise [OctaSpace::WaitTimeoutError] the timeout ran out
      def wait_stopped(uuid, timeout: nil, interval: DEFAULT_WAIT_INTERVAL)
        poll(timeout, interval) do
          get(uuid)
          nil
        rescue NotFoundError
          true
        end
      end

      private

      def get_raw(path, **opts) = transport.get(path, **opts)

      def session_path(uuid, action) = "/services/#{encode(uuid)}/#{action}"

      def poll(timeout, interval)
        deadline = timeout && (monotonic + timeout)
        loop do
          result = yield
          return result if result
          if deadline && monotonic + interval > deadline
            raise WaitTimeoutError, "Gave up waiting after #{timeout} seconds"
          end

          @sleeper.call(interval)
        end
      end

      def monotonic = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    end
  end
end

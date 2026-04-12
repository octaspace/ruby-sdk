# frozen_string_literal: true

module OctaSpace
  module Resources
    # Session listing endpoint
    #
    # For operations on a specific session (info/logs/stop),
    # use the proxy pattern: client.services.session("uuid")
    #
    # @example
    #   client.sessions.list
    #   client.sessions.list(recent: true)
    class Sessions < Base
      # List all sessions
      # GET /sessions
      # @param params [Hash] optional filter params
      # @return [OctaSpace::Response]
      def list(**params)
        get("/sessions", params:)
      end
    end
  end
end

# frozen_string_literal: true

require "uri"

module OctaSpace
  module Resources
    class Services
      # Proxy object for operations on a specific service session
      #
      # Obtained via: client.services.session("uuid")
      #
      # @example
      #   session = client.services.session("abc-123")
      #   session.info
      #   session.logs
      #   session.stop(score: 5)
      class SessionProxy
        # @param transport [OctaSpace::Transport::Base]
        # @param uuid [String] session UUID
        def initialize(transport, uuid)
          @transport = transport
          @uuid = URI.encode_www_form_component(uuid.to_s)
        end

        # Fetch session details
        # GET /services/:uuid/info
        # @return [OctaSpace::Response]
        def info
          @transport.get("/services/#{@uuid}/info")
        end

        # Fetch session logs
        # GET /services/:uuid/logs
        # @return [OctaSpace::Response]
        def logs
          @transport.get("/services/#{@uuid}/logs")
        end

        # Stop the session
        # POST /services/:uuid/stop
        # @param params [Hash] e.g. { score: 5 }
        # @return [OctaSpace::Response]
        def stop(**params)
          @transport.post("/services/#{@uuid}/stop", body: params.empty? ? nil : params)
        end
      end
    end
  end
end

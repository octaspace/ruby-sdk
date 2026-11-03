# frozen_string_literal: true

module OctaSpace
  module Resources
    # Legacy session proxy: client.services.session("uuid").info / logs / stop
    class Services < Base
      # Return a proxy object for operations on a specific session
      # @param uuid [String] session UUID
      # @return [OctaSpace::Resources::Services::SessionProxy]
      def session(uuid)
        Services::SessionProxy.new(transport, uuid)
      end
    end
  end
end

require_relative "services/session_proxy"

# frozen_string_literal: true

require_relative "services/session_proxy"
require_relative "services/machine_rental"
require_relative "services/vpn"
require_relative "services/render"

module OctaSpace
  module Resources
    # Services namespace — aggregates MR, VPN, Render subresources
    # and provides the session proxy pattern
    #
    # @example
    #   client.services.mr.list
    #   client.services.vpn.create(node_id: 123)
    #   client.services.render.create(node_id: 456, app_id: 7)
    #
    #   # Session proxy pattern
    #   client.services.session("uuid-123").info
    #   client.services.session("uuid-123").stop(score: 5)
    class Services < Base
      attr_reader :mr, :vpn, :render

      def initialize(transport)
        super
        @mr     = Services::MachineRental.new(transport)
        @vpn    = Services::Vpn.new(transport)
        @render = Services::Render.new(transport)
      end

      # Return a proxy object for operations on a specific session
      # @param uuid [String] session UUID
      # @return [OctaSpace::Resources::Services::SessionProxy]
      def session(uuid)
        Services::SessionProxy.new(transport, uuid)
      end
    end
  end
end

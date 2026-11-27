# frozen_string_literal: true

module OctaSpace
  module Resources
    # VPN nodes: listing and start.
    #
    # @example
    #   node = client.vpn.list.select { |n| n.supports?(:wg) }.min_by(&:traffic_price)
    #   uuid = client.vpn.start(node_number: node.node_number, subkind: "wg")
    #   client.sessions.wait_ready(uuid).config # => WireGuard config file
    class Vpn < Base
      # Protocols a VPN session can use: WireGuard, AmneziaWG, VLESS Reality
      # and an HTTP proxy with a login
      PROTOCOLS = %w[wg awg reality http_proxy].freeze

      # Nodes offered for VPN.
      # GET /services/vpn
      #
      # Works without an API key, but is then refreshed about once an hour;
      # with a key it is at most 10 seconds old.
      # @return [Array<OctaSpace::Types::VpnMachine>]
      def list
        Types::VpnMachine.wrap_all(JsonNull.null_strings!(Array(get("/services/vpn", auth: :optional).data)))
      end

      # Starts a VPN session, billed by traffic until stopped.
      # POST /services/vpn
      #
      # Pick +subkind+ from the node's +protocols+: a protocol the node did not
      # pass its connection check for is refused. You can have one VPN session
      # per node. Once +client.sessions.wait_ready+ returns the session, its
      # +config+ is what the client connects with. An +http_proxy+ session
      # accepts connections only from the IP address that started it.
      #
      # Raises {OctaSpace::ValidationError} when the start is refused, for
      # example "Insufficient balance", "Node not found", "You already have a
      # VPN session on this node" or "Node's VPN did not pass the connection
      # check". Never retried automatically.
      #
      # @param node_number [String] node number from {#list}
      # @param subkind [String, Symbol] one of {PROTOCOLS}
      # @return [String] the session uuid
      def start(node_number:, subkind:)
        post("/services/vpn", body: {node_number: node_number, subkind: subkind.to_s}).data.fetch("uuid")
      end
    end
  end
end

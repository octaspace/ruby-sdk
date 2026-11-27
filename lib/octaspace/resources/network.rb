# frozen_string_literal: true

module OctaSpace
  module Resources
    # Platform statistics; no API key needed
    #
    # @example
    #   client.network.info.nodes.online
    #   client.network.history(from: Time.now - 7 * 86_400).points.last.nodes_online
    class Network < Base
      # Platform statistics now: nodes, capacity, sessions, users, rendered
      # frames and VPN nodes.
      # GET /network
      #
      # Raises {OctaSpace::ServiceUnavailableError} while it is unavailable.
      # @return [OctaSpace::Types::Network]
      def info
        Types::Network.new(get_public("/network"))
      end

      # Platform statistics over time, one point per +step+. Each value is the
      # average over its step, so it can be fractional. Defaults to the last
      # day with hourly points. Invalid ranges (step < 300, too many points,
      # from after to) raise {OctaSpace::ValidationError}.
      # GET /network/history
      #
      # @param from [Time, Integer, nil] range start (Unix seconds); a day before +to+ by default
      # @param to [Time, Integer, nil] range end (Unix seconds); now by default
      # @param step [Integer, nil] seconds between points, at least 300 (default 3600);
      #   at most 2000 points
      # @return [OctaSpace::Types::NetworkHistory]
      def history(from: nil, to: nil, step: nil)
        Types::NetworkHistory.new(get_public("/network/history", start: unix(from), end: unix(to), step: step))
      end
    end
  end
end

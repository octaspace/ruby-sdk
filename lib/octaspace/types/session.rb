# frozen_string_literal: true

module OctaSpace
  module Types
    # Value object representing a service session
    Session = Data.define(:uuid, :service, :app_name, :node_id, :urls, :prices, :node_hw) do
      # @return [String]
      def to_s = "Session <#{uuid}> #{service}"
    end
  end
end

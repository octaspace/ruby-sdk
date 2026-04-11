# frozen_string_literal: true

module OctaSpace
  module Types
    # Value object representing a compute node
    # @note Requires Ruby 3.2+ for Data.define
    Node = Data.define(:id, :ip, :state, :location, :prices, :system) do
      # @return [Boolean]
      def online?  = state == "online"
      def offline? = !online?
    end
  end
end

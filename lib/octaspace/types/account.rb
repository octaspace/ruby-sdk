# frozen_string_literal: true

module OctaSpace
  module Types
    # Value object representing an OctaSpace account
    # @note Requires Ruby 3.2+ for Data.define
    Account = Data.define(:account_uuid, :email, :avatar, :balance) do
      # @return [String]
      def to_s = "OctaSpace Account <#{email}>"
    end
  end
end

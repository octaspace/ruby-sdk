# frozen_string_literal: true

module OctaSpace
  module Resources
    # Apps API endpoint
    #
    # @example
    #   client.apps.list
    class Apps < Base
      # List available apps
      # GET /apps
      # @param params [Hash] optional filter params
      # @return [OctaSpace::Response]
      def list(**params)
        get("/apps", params: params)
      end
    end
  end
end

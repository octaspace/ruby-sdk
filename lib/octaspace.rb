# frozen_string_literal: true

require "octaspace/version"
require "octaspace/errors"
require "octaspace/response"
require "octaspace/configuration"
require "octaspace/middleware/url_rotator"
require "octaspace/transport/base"
require "octaspace/transport/faraday_transport"
require "octaspace/types/account"
require "octaspace/types/balance"
require "octaspace/types/node"
require "octaspace/types/session"
require "octaspace/resources/base"
require "octaspace/resources/accounts"
require "octaspace/resources/nodes"
require "octaspace/resources/sessions"
require "octaspace/resources/apps"
require "octaspace/resources/network"
require "octaspace/resources/services"
require "octaspace/resources/idle_jobs"
require "octaspace/client"

# OctaSpace Ruby SDK
#
# Official Ruby client for the OctaSpace API.
# Supports standard and keep-alive (persistent) connection modes,
# automatic URL rotation/failover, retry with exponential backoff,
# and optional Rails integration.
#
# @example Quick start
#   OctaSpace.configure do |config|
#     config.api_key = ENV["OCTA_API_KEY"]
#   end
#
#   client = OctaSpace.client
#   client.nodes.list
#   client.accounts.balance
#
# @see https://api.octa.space/api-docs
module OctaSpace
  class << self
    # Global configuration object
    # @return [OctaSpace::Configuration]
    def configuration
      @configuration ||= Configuration.new
    end

    # Configure the SDK globally
    #
    # @example
    #   OctaSpace.configure do |config|
    #     config.api_key    = ENV["OCTA_API_KEY"]
    #     config.keep_alive = true
    #     config.pool_size  = ENV.fetch("RAILS_MAX_THREADS", 5).to_i
    #   end
    # @yield [OctaSpace::Configuration]
    def configure
      yield configuration
    end

    # Reset global configuration to defaults (useful in tests)
    def reset_configuration!
      @configuration = Configuration.new
    end

    # Convenience factory: create a client using global configuration
    #
    # @param api_key [String, nil] override global api_key for this client
    # @param opts [Hash] additional per-client configuration overrides
    # @return [OctaSpace::Client]
    def client(api_key: nil, **opts)
      Client.new(api_key: api_key || configuration.api_key, **opts)
    end
  end
end

# Auto-load Rails integration when Rails is present
require "octaspace/railtie" if defined?(Rails::Railtie)

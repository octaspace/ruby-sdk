# frozen_string_literal: true

module OctaSpace
  # Rails integration via Railtie
  #
  # Automatically loaded when Rails is present (see lib/octaspace.rb).
  # Allows configuration via config/initializers/octaspace.rb:
  #
  #   OctaSpace.configure do |config|
  #     config.api_key    = ENV["OCTA_API_KEY"]
  #     config.keep_alive = true
  #     config.pool_size  = ENV.fetch("RAILS_MAX_THREADS", 5).to_i
  #     config.logger     = Rails.logger
  #   end
  class Railtie < ::Rails::Railtie
    initializer "octaspace.configure" do
      # No-op: users call OctaSpace.configure {} directly in their initializer.
      # This hook exists for future extensions (e.g., auto-configure from credentials).
    end

    # Gracefully shut down the shared client's persistent connection pools
    # when the Rails process stops. Only applies when keep_alive: true is used
    # and the shared client (OctaSpace.client) has been accessed.
    config.after_initialize do
      at_exit { OctaSpace.shutdown_shared_client! }
    end
  end
end

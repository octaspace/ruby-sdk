# frozen_string_literal: true

OctaSpace.configure do |config|
  config.api_key    = ENV.fetch("OCTA_API_KEY", nil)
  config.keep_alive = ENV["OCTASPACE_KEEP_ALIVE"] == "true"
  config.pool_size  = ENV.fetch("RAILS_MAX_THREADS", 5).to_i
  # Keep the playground responsive by default; override with OCTASPACE_MAX_RETRIES if needed.
  config.max_retries = ENV.fetch("OCTASPACE_MAX_RETRIES", 0).to_i
  config.logger     = Rails.logger
end

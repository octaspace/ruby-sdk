# frozen_string_literal: true

require_relative "boot"

require "rails"
require "action_controller/railtie"
require "action_view/railtie"

# Load the gem itself
$LOAD_PATH.unshift File.expand_path("../../../lib", __dir__)
require "octaspace"

module Dummy
  class Application < Rails::Application
    config.load_defaults 8.0
    config.eager_load    = false
    config.secret_key_base = "dummy_secret_key_base_for_playground_only"
    config.logger = Logger.new($stdout)
    config.log_level = :info
  end
end

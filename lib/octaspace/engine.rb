# frozen_string_literal: true

module OctaSpace
  # Optional Rails Engine
  #
  # Mount only if you need the built-in playground routes:
  #
  #   # config/routes.rb
  #   mount OctaSpace::Engine, at: "/octaspace"
  #
  # This is NOT auto-loaded. Load explicitly when needed:
  #   require "octaspace/engine"
  class Engine < ::Rails::Engine
    isolate_namespace OctaSpace
  end
end

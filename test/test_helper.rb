# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

require "octaspace"
require "minitest/autorun"
require "webmock/minitest"

require_relative "support/fixture_helpers"
require_relative "support/stub_helpers"

# Disable all real HTTP connections in tests
WebMock.disable_net_connect!

module Minitest
  class Test
    include FixtureHelpers
    include StubHelpers

    # Reset global config before each test
    def setup
      OctaSpace.reset_configuration!
    end
  end
end

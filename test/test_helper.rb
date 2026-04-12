# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

require "octaspace"
require "octaspace/transport/mock_transport"
require "minitest/autorun"
require "minitest/mock"
require "webmock/minitest"

require_relative "support/fixture_helpers"
require_relative "support/stub_helpers"

# Filter gem/framework internals from failure backtraces
Minitest.backtrace_filter = Minitest::BacktraceFilter.new

# Disable all real HTTP connections in tests
WebMock.disable_net_connect!

module Minitest
  class Test
    include FixtureHelpers
    include StubHelpers

    # Reset global config and shared client before each test
    def setup
      OctaSpace.reset_configuration!
      # Keep error-path tests fast; production clients still use the normal retry defaults.
      OctaSpace.configure do |config|
        config.max_retries = 0
      end
    end
  end
end

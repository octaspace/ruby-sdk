# frozen_string_literal: true

require "securerandom"

module OctaSpace
  module Transport
    # Fixture-backed mock transport used by the playground and tests.
    #
    # Supports one happy-path fixture mode plus the same error-oriented
    # scenarios exposed in the JS playground.
    class MockTransport < Base
      SCENARIOS = [
        {value: "real", label: "Real API", description: "Use the actual OctaSpace API"},
        {value: "401", label: "401 Unauthorized", description: "Simulates invalid or missing API key"},
        {value: "403", label: "403 Forbidden", description: "Simulates insufficient permissions"},
        {value: "404", label: "404 Not Found", description: "Simulates a missing resource"},
        {value: "429", label: "429 Rate Limited", description: "Simulates rate limiting with Retry-After: 60"},
        {value: "500", label: "500 Server Error", description: "Simulates an internal server error"},
        {value: "slow", label: "Slow (3s)", description: "Adds a 3-second delay before responding with fixtures"},
        {value: "timeout", label: "Timeout", description: "Raises a timeout error without contacting the API"},
        {value: "network-error", label: "Network Error", description: "Simulates a connection failure"}
      ].freeze

      DEFAULT_DELAY_SECONDS = 3.0
      RawResponse = Struct.new(:status, :headers, :body, keyword_init: true)

      def self.scenarios = SCENARIOS

      def initialize(config, scenario:, delay_seconds: DEFAULT_DELAY_SECONDS)
        @config = config
        @scenario = scenario.to_s
        @delay_seconds = delay_seconds
      end

      attr_reader :scenario

      def get(path, params: {}, headers: {})
        request(:get, path, params: params, headers: headers)
      end

      def post(path, body: nil, headers: {})
        request(:post, path, body: body, headers: headers)
      end

      def put(path, body: nil, headers: {})
        request(:put, path, body: body, headers: headers)
      end

      def patch(path, body: nil, headers: {})
        request(:patch, path, body: body, headers: headers)
      end

      def delete(path, params: {}, headers: {})
        request(:delete, path, params: params, headers: headers)
      end

      def transport_stats
        {
          mode: :mock,
          scenario: scenario,
          label: scenario_metadata[:label]
        }
      end

      private

      attr_reader :config, :delay_seconds

      def request(method, path, params: {}, body: nil, headers: {})
        invoke_hook(config.on_request, {method: method, path: path, params: params, body: body, headers: headers})

        simulate_transport_failure!
        simulate_delay! if scenario == "slow"

        raise ConfigurationError, "MockTransport cannot be used with the real scenario" if scenario == "real"

        response = build_mock_response

        invoke_hook(config.on_response, response)
        raise OctaSpace.error_for(response) if response.error?

        response
      end

      def mock_response_scenario?
        %w[401 403 404 429 500 slow].include?(scenario)
      end

      def simulate_transport_failure!
        case scenario
        when "network-error"
          raise ConnectionError, "Mocked network failure"
        when "timeout"
          raise TimeoutError, "Mocked timeout after #{config.read_timeout}s"
        end
      end

      def simulate_delay!
        sleep(delay_seconds)
      end

      def build_mock_response
        status = (scenario == "slow") ? 200 : scenario.to_i
        headers = {"content-type" => "application/json"}
        headers["retry-after"] = "60" if scenario == "429"

        build_response(
          status: status,
          headers: headers,
          body: {"error" => "Mocked #{status}", "scenario" => scenario}
        )
      end

      def build_response(status:, body:, headers: {})
        response_headers = {
          "content-type" => "application/json",
          "x-request-id" => "mock-#{SecureRandom.hex(6)}"
        }.merge(headers)

        Response.new(
          RawResponse.new(
            status: status,
            headers: response_headers,
            body: body
          )
        )
      end

      def scenario_metadata
        self.class.scenarios.find { |entry| entry[:value] == scenario } || self.class.scenarios.first
      end

      def invoke_hook(hook, *args)
        hook&.call(*args)
      end
    end
  end
end

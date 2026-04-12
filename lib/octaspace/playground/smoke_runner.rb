# frozen_string_literal: true

require "time"

module OctaSpace
  module Playground
    class SmokeRunner
      SUITES = [
        {
          id: "network.info",
          label: "octa_client.network.info",
          method: "GET",
          path: "/network",
          requires_auth: false,
          fn: ->(client) { client.network.info }
        },
        {
          id: "accounts.profile",
          label: "octa_client.accounts.profile",
          method: "GET",
          path: "/accounts",
          requires_auth: true,
          fn: ->(client) { client.accounts.profile }
        },
        {
          id: "accounts.balance",
          label: "octa_client.accounts.balance",
          method: "GET",
          path: "/accounts/balance",
          requires_auth: true,
          fn: ->(client) { client.accounts.balance }
        },
        {
          id: "apps.list",
          label: "octa_client.apps.list",
          method: "GET",
          path: "/apps",
          requires_auth: true,
          fn: ->(client) { client.apps.list }
        },
        {
          id: "nodes.list",
          label: "octa_client.nodes.list",
          method: "GET",
          path: "/nodes",
          requires_auth: true,
          fn: ->(client) { client.nodes.list }
        },
        {
          id: "services.mr.list",
          label: "octa_client.services.mr.list",
          method: "GET",
          path: "/services/mr",
          requires_auth: true,
          fn: ->(client) { client.services.mr.list }
        },
        {
          id: "services.render.list",
          label: "octa_client.services.render.list",
          method: "GET",
          path: "/services/render",
          requires_auth: true,
          fn: ->(client) { client.services.render.list }
        },
        {
          id: "services.vpn.list",
          label: "octa_client.services.vpn.list",
          method: "GET",
          path: "/services/vpn",
          requires_auth: true,
          fn: ->(client) { client.services.vpn.list }
        },
        {
          id: "sessions.list",
          label: "octa_client.sessions.list",
          method: "GET",
          path: "/sessions",
          requires_auth: true,
          fn: ->(client) { client.sessions.list }
        },
        {
          id: "sessions.list.recent",
          label: "octa_client.sessions.list(recent: true)",
          method: "GET",
          path: "/sessions?recent=true",
          requires_auth: true,
          fn: ->(client) { client.sessions.list(recent: true) }
        }
      ].freeze

      def initialize(client:, executor: nil)
        @client = client
        @executor = executor || method(:default_execute)
      end

      def run
        started_at = monotonic_now
        suites = SUITES.map { |suite| run_suite(suite) }
        passed_count = suites.count { |suite| suite[:status] == "passed" }
        failed_count = suites.count { |suite| suite[:status] == "failed" }

        {
          kind: "sdk_smoke",
          status: failed_count.zero? ? "passed" : "failed",
          started_at: Time.now.utc.iso8601,
          duration_ms: elapsed_ms(started_at),
          summary: {
            total: suites.length,
            passed: passed_count,
            failed: failed_count
          },
          suites:
        }
      end

      private

      attr_reader :client, :executor

      def run_suite(suite)
        started_at = monotonic_now
        response = executor.call(suite) { suite[:fn].call(client) }

        if response.is_a?(OctaSpace::Error)
          {
            id: suite[:id],
            label: suite[:label],
            method: suite[:method],
            path: suite[:path],
            requires_auth: suite[:requires_auth],
            status: "failed",
            duration_ms: elapsed_ms(started_at),
            error: {
              class: response.class.name,
              message: response.message,
              status: response.status,
              request_id: response.request_id
            }.compact
          }
        else
          {
            id: suite[:id],
            label: suite[:label],
            method: suite[:method],
            path: suite[:path],
            requires_auth: suite[:requires_auth],
            status: "passed",
            duration_ms: elapsed_ms(started_at),
            http_status: response.status,
            request_id: response.request_id,
            summary: summarize_payload(response.data)
          }.compact
        end
      rescue => e
        {
          id: suite[:id],
          label: suite[:label],
          method: suite[:method],
          path: suite[:path],
          requires_auth: suite[:requires_auth],
          status: "failed",
          duration_ms: elapsed_ms(started_at),
          error: {
            class: e.class.name,
            message: e.message
          }
        }
      end

      def summarize_payload(payload)
        case payload
        when Array
          {
            type: "array",
            count: payload.length,
            sample_keys: payload.first.is_a?(Hash) ? payload.first.keys.take(8) : nil
          }.compact
        when Hash
          {
            type: "object",
            keys: payload.keys.take(12)
          }
        else
          {
            type: payload.class.name,
            value: payload
          }
        end
      end

      def default_execute(_suite)
        yield
      end

      def monotonic_now
        Process.clock_gettime(Process::CLOCK_MONOTONIC)
      end

      def elapsed_ms(started_at)
        ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at) * 1000).round
      end
    end
  end
end

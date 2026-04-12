# frozen_string_literal: true

module Playground
  class DiagnosticsController < BaseController
    SDK_CALLS = [
      {
        id: "network.info",
        label: "octa_client.network.info",
        description: "GET /network — public, no auth required",
        method: "GET",
        path: "/network",
        requires_auth: false
      },
      {
        id: "accounts.profile",
        label: "octa_client.accounts.profile",
        description: "GET /accounts — requires API key",
        method: "GET",
        path: "/accounts",
        requires_auth: true
      },
      {
        id: "accounts.balance",
        label: "octa_client.accounts.balance",
        description: "GET /accounts/balance — requires API key",
        method: "GET",
        path: "/accounts/balance",
        requires_auth: true
      },
      {
        id: "apps.list",
        label: "octa_client.apps.list",
        description: "GET /apps — requires API key",
        method: "GET",
        path: "/apps",
        requires_auth: true
      },
      {
        id: "idle_jobs.find",
        label: "octa_client.idle_jobs.find(node_id:, job_id:)",
        description: "GET /idle_jobs/:node_id/:job_id — requires API key",
        method: "GET",
        path: "/idle_jobs/:node_id/:job_id",
        requires_auth: true,
        payload: true
      },
      {
        id: "idle_jobs.logs",
        label: "octa_client.idle_jobs.logs(node_id:, job_id:)",
        description: "GET /idle_jobs/:node_id/:job_id/logs — requires API key",
        method: "GET",
        path: "/idle_jobs/:node_id/:job_id/logs",
        requires_auth: true,
        payload: true
      },
      {
        id: "nodes.list",
        label: "octa_client.nodes.list",
        description: "GET /nodes — requires API key",
        method: "GET",
        path: "/nodes",
        requires_auth: true
      },
      {
        id: "sessions.list",
        label: "octa_client.sessions.list",
        description: "GET /sessions — requires API key",
        method: "GET",
        path: "/sessions",
        requires_auth: true
      },
      {
        id: "sessions.list.recent",
        label: "octa_client.sessions.list(recent: true)",
        description: "GET /sessions?recent=true — requires API key",
        method: "GET",
        path: "/sessions?recent=true",
        requires_auth: true
      },
      {
        id: "services.mr.list",
        label: "octa_client.services.mr.list",
        description: "GET /services/mr — requires API key",
        method: "GET",
        path: "/services/mr",
        requires_auth: true
      },
      {
        id: "services.render.list",
        label: "octa_client.services.render.list",
        description: "GET /services/render — requires API key",
        method: "GET",
        path: "/services/render",
        requires_auth: true
      },
      {
        id: "services.vpn.list",
        label: "octa_client.services.vpn.list",
        description: "GET /services/vpn — requires API key",
        method: "GET",
        path: "/services/vpn",
        requires_auth: true
      },
      {
        id: "services.mr.create",
        label: "octa_client.services.mr.create",
        description: "POST /services/mr — requires API key",
        method: "POST",
        path: "/services/mr",
        requires_auth: true,
        mutation: true
      },
      {
        id: "services.render.create",
        label: "octa_client.services.render.create",
        description: "POST /services/render — requires API key",
        method: "POST",
        path: "/services/render",
        requires_auth: true,
        mutation: true
      },
      {
        id: "services.vpn.create",
        label: "octa_client.services.vpn.create",
        description: "POST /services/vpn — requires API key",
        method: "POST",
        path: "/services/vpn",
        requires_auth: true,
        mutation: true
      },
      {
        id: "services.session.stop",
        label: "octa_client.services.session(uuid).stop",
        description: "POST /services/:uuid/stop — requires API key",
        method: "POST",
        path: "/services/:uuid/stop",
        requires_auth: true,
        mutation: true
      }
    ].freeze

    def show
      prepare_state
      @payload_json =
        if call_uses_payload?(@selected_call)
          params[:payload_json].presence || default_payload_json(@selected_call)
        else
          ""
        end
    end

    def run
      prepare_state
      @selected_call = find_call(params[:call])
      @selected_call_id = @selected_call[:id]
      @payload_json = params[:payload_json].to_s
      @payload_json = default_payload_json(@selected_call) if @payload_json.empty? && call_uses_payload?(@selected_call)

      started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      @result = execute_call(@selected_call)
      @result[:duration_ms] = duration_ms(started_at)
      render :show
    end

    def smoke
      prepare_state
      @payload_json = default_payload_json(@selected_call)
      runner = OctaSpace::Playground::SmokeRunner.new(client: octa_client, executor: method(:execute_smoke_suite))
      smoke_result = runner.run
      @result = {
        status: :smoke,
        duration_ms: smoke_result[:duration_ms],
        data: smoke_result
      }
      render :show
    rescue StandardError => e
      @result = {status: :error, error: wrap_smoke_error(e)}
      render :show
    end

    private

    def prepare_state
      @config = playground_config
      @transport_stats = playground_transport_stats
      @rotator_stats = extract_rotator_stats
      @calls = SDK_CALLS
      @selected_call_id = params[:call].presence || @calls.first[:id]
      @selected_call = find_call(@selected_call_id)
      @result = {status: :idle}
    end

    def find_call(call_id)
      @calls.find { |call| call[:id] == call_id } || @calls.first
    end

    def execute_call(call)
      payload = call_uses_payload?(call) ? parse_payload!(call, @payload_json) : nil
      path = resolved_path(call, payload)

      response = capture_api_call(label: call[:label], method: call[:method], path:) do
        case call[:id]
        when "network.info"
          octa_client.network.info
        when "accounts.profile"
          octa_client.accounts.profile
        when "accounts.balance"
          octa_client.accounts.balance
        when "apps.list"
          octa_client.apps.list
        when "idle_jobs.find"
          octa_client.idle_jobs.find(node_id: payload.fetch(:node_id), job_id: payload.fetch(:job_id))
        when "idle_jobs.logs"
          octa_client.idle_jobs.logs(node_id: payload.fetch(:node_id), job_id: payload.fetch(:job_id))
        when "nodes.list"
          octa_client.nodes.list
        when "sessions.list"
          octa_client.sessions.list
        when "sessions.list.recent"
          octa_client.sessions.list(recent: true)
        when "services.mr.list"
          octa_client.services.mr.list
        when "services.render.list"
          octa_client.services.render.list
        when "services.vpn.list"
          octa_client.services.vpn.list
        when "services.mr.create"
          octa_client.services.mr.create(**payload)
        when "services.render.create"
          octa_client.services.render.create(**payload)
        when "services.vpn.create"
          octa_client.services.vpn.create(**payload)
        when "services.session.stop"
          uuid = payload.fetch(:uuid).to_s
          octa_client.services.session(uuid).stop(**payload.except(:uuid))
        end
      end

      return {status: :error, error: response} if response.is_a?(OctaSpace::Error)

      {status: :success, data: response.data, response: response}
    rescue OctaSpace::Error => e
      {status: :error, error: e}
    end

    def duration_ms(started_at)
      ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at) * 1000).round
    end

    def execute_smoke_suite(suite)
      capture_api_call(label: suite[:label], method: suite[:method], path: suite[:path]) { yield }
    end

    def default_payload_json(call)
      return "" unless call_uses_payload?(call)

      OctaSpace::Playground::PayloadPresets.payload_json_for(call[:id])
    end

    def parse_payload!(call, payload_json)
      if payload_json.blank?
        raise OctaSpace::ValidationError.new("Payload JSON is required for #{call[:label]}")
      end

      payload = JSON.parse(payload_json)
      raise OctaSpace::ValidationError.new("Payload JSON must be an object") unless payload.is_a?(Hash)

      payload = payload.deep_symbolize_keys
      validate_mutation_payload!(call, payload)
      payload
    rescue JSON::ParserError => e
      raise OctaSpace::ValidationError.new("Invalid payload JSON: #{e.message}")
    end

    def validate_mutation_payload!(call, payload)
      case call[:id]
      when "services.session.stop"
        raise OctaSpace::ValidationError.new("Payload must include a non-empty uuid") if payload[:uuid].to_s.strip.empty?
      when "idle_jobs.find", "idle_jobs.logs"
        raise OctaSpace::ValidationError.new("Payload must include node_id") if payload[:node_id].to_s.strip.empty?
        raise OctaSpace::ValidationError.new("Payload must include job_id") if payload[:job_id].to_s.strip.empty?
      end
    end

    def resolved_path(call, payload)
      case call[:id]
      when "services.session.stop"
        "/services/#{payload.fetch(:uuid)}/stop"
      when "idle_jobs.find"
        "/idle_jobs/#{payload.fetch(:node_id)}/#{payload.fetch(:job_id)}"
      when "idle_jobs.logs"
        "/idle_jobs/#{payload.fetch(:node_id)}/#{payload.fetch(:job_id)}/logs"
      else
        call[:path]
      end
    end

    def call_uses_payload?(call)
      call[:mutation] || call[:payload]
    end

    def wrap_smoke_error(error)
      return error if error.is_a?(OctaSpace::Error)

      OctaSpace::Error.new("Smoke runner failed: #{error.message}")
    end

    def extract_rotator_stats
      transport = octa_client.instance_variable_get(:@transport)
      rotator = transport.instance_variable_get(:@rotator)
      rotator&.stats
    end
  end
end

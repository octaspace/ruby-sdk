# frozen_string_literal: true

module Playground
  class IdleJobsController < BaseController
    def show
      @node_id = params[:node_id].presence || default_payload[:node_id].to_s
      @job_id = params[:job_id].presence || default_payload[:job_id].to_s

      return if params[:node_id].blank? || params[:job_id].blank?

      @job = capture_api_call(
        label: "octa_client.idle_jobs.find(node_id: #{@node_id}, job_id: #{@job_id})",
        path: "/idle_jobs/#{@node_id}/#{@job_id}"
      ) do
        octa_client.idle_jobs.find(node_id: @node_id, job_id: @job_id)
      end

      @logs = capture_api_call(
        label: "octa_client.idle_jobs.logs(node_id: #{@node_id}, job_id: #{@job_id})",
        path: "/idle_jobs/#{@node_id}/#{@job_id}/logs"
      ) do
        octa_client.idle_jobs.logs(node_id: @node_id, job_id: @job_id)
      end
    end

    private

    def default_payload
      OctaSpace::Playground::PayloadPresets.payload_for("idle_jobs.find")
    end
  end
end

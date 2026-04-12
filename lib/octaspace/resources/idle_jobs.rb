# frozen_string_literal: true

module OctaSpace
  module Resources
    # Idle Jobs API endpoints
    #
    # Each idle job is identified by both a node ID and a job ID.
    #
    # @example
    #   client.idle_jobs.find(node_id: 69, job_id: 42)
    #   client.idle_jobs.logs(node_id: 69, job_id: 42)
    class IdleJobs < Base
      # Fetch a single idle job status
      # GET /idle_jobs/:node_id/:job_id
      # @param node_id [Integer, String]
      # @param job_id [Integer, String]
      # @return [OctaSpace::Response]
      def find(node_id:, job_id:)
        get("/idle_jobs/#{encode(node_id)}/#{encode(job_id)}")
      end

      # Fetch idle job logs
      # GET /idle_jobs/:node_id/:job_id/logs
      # @param node_id [Integer, String]
      # @param job_id [Integer, String]
      # @return [OctaSpace::Response]
      def logs(node_id:, job_id:)
        get("/idle_jobs/#{encode(node_id)}/#{encode(job_id)}/logs")
      end
    end
  end
end

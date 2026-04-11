# frozen_string_literal: true

module OctaSpace
  module Resources
    # Idle Jobs API endpoints
    #
    # @example
    #   client.idle_jobs.list
    #   client.idle_jobs.find(42)
    #   client.idle_jobs.create(node_id: 1, command: "sleep 60")
    #   client.idle_jobs.logs(42)
    class IdleJobs < Base
      # List all idle jobs
      # GET /idle-jobs
      # @param params [Hash] optional filter params
      # @return [OctaSpace::Response]
      def list(**params)
        get("/idle-jobs", params: params)
      end

      # Fetch a single idle job by ID
      # GET /idle-jobs/:id
      # @param id [Integer, String]
      # @return [OctaSpace::Response]
      def find(id)
        get("/idle-jobs/#{id}")
      end

      # Create an idle job
      # POST /idle-jobs
      # @param attrs [Hash] job parameters
      # @return [OctaSpace::Response]
      def create(**attrs)
        post("/idle-jobs", body: attrs)
      end

      # Fetch idle job logs
      # GET /idle-jobs/:id/logs
      # @param id [Integer, String]
      # @return [OctaSpace::Response]
      def logs(id)
        get("/idle-jobs/#{id}/logs")
      end
    end
  end
end

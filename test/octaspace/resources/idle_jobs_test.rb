# frozen_string_literal: true

require "test_helper"

class OctaSpace::IdleJobsResourceTest < Minitest::Test
  def setup
    super
    @client = test_client
  end

  def test_find_returns_single_job
    stub_get("/idle_jobs/69/42", fixture_path: "idle_jobs/show.json")
    response = @client.idle_jobs.find(node_id: 69, job_id: 42)
    assert response.success?
    assert_equal 42, response.data["id"]
    assert_equal "completed", response.data["status"]
  end

  def test_find_raises_not_found
    stub_error(:get, "/idle_jobs/69/99999", status: 404, message: "Job not found")
    assert_raises(OctaSpace::NotFoundError) { @client.idle_jobs.find(node_id: 69, job_id: 99999) }
  end

  def test_logs_returns_data
    stub_get("/idle_jobs/69/42/logs", fixture_path: "idle_jobs/logs.json")
    response = @client.idle_jobs.logs(node_id: 69, job_id: 42)
    assert response.success?
  end

  def test_logs_raises_authentication_error_on_401
    stub_error(:get, "/idle_jobs/69/42", status: 401, message: "Unauthorized")
    assert_raises(OctaSpace::AuthenticationError) { @client.idle_jobs.find(node_id: 69, job_id: 42) }
  end
end

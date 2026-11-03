# frozen_string_literal: true

require "test_helper"

class OctaSpace::ResponseTest < Minitest::Test
  def make_response(status:, body: {}, headers: {})
    OctaSpace::Response.new(
      status: status,
      headers: Faraday::Utils::Headers.new({"content-type" => "application/json"}.merge(headers)),
      body: JSON.generate(body),
      data: body
    )
  end

  # --- Status predicates ---

  def test_success_on_200
    assert make_response(status: 200).success?
  end

  def test_success_on_201
    assert make_response(status: 201).success?
  end

  def test_success_on_204
    assert make_response(status: 204).success?
  end

  def test_not_success_on_400
    refute make_response(status: 400).success?
  end

  def test_client_error_on_404
    r = make_response(status: 404)
    assert r.client_error?
    refute r.server_error?
    assert r.error?
  end

  def test_server_error_on_500
    r = make_response(status: 500)
    assert r.server_error?
    refute r.client_error?
    assert r.error?
  end

  def test_not_error_on_200
    refute make_response(status: 200).error?
  end

  # --- Headers ---

  def test_request_id_from_header
    r = make_response(status: 200, headers: {"x-request-id" => "req-abc-123"})
    assert_equal "req-abc-123", r.request_id
  end

  def test_request_id_nil_when_missing
    assert_nil make_response(status: 200).request_id
  end

  def test_retry_after_from_header
    r = make_response(status: 429, headers: {"retry-after" => "60"})
    assert_equal 60, r.retry_after
  end

  def test_retry_after_nil_when_missing
    assert_nil make_response(status: 200).retry_after
  end

  # --- Data ---

  def test_data_is_parsed_body
    body = {"id" => 1, "name" => "test"}
    r = make_response(status: 200, body: body)
    assert_equal body, r.data
    assert_equal JSON.generate(body), r.body
  end

  def test_retry_after_fraction_rounds_up
    assert_equal 2, make_response(status: 429, headers: {"Retry-After" => "1.2"}).retry_after
  end

  def test_retry_after_http_date
    date = (Time.now + 30).httpdate
    assert_in_delta 30, make_response(status: 429, headers: {"Retry-After" => date}).retry_after, 2
  end

  def test_retry_after_garbage_is_nil
    assert_nil make_response(status: 429, headers: {"Retry-After" => "soon"}).retry_after
  end

  def test_rate_limit_from_headers
    r = make_response(status: 200, headers: {"RateLimit-Limit" => "300", "RateLimit-Remaining" => "12"})
    assert_equal OctaSpace::RateLimit.new(limit: 300, remaining: 12, reset: nil), r.rate_limit
  end

  def test_rate_limit_nil_without_headers_or_with_garbage
    assert_nil make_response(status: 200).rate_limit
    assert_nil make_response(status: 200, headers: {"RateLimit-Limit" => "many"}).rate_limit
  end

  def test_data_array
    body = [{"id" => 1}, {"id" => 2}]
    r = make_response(status: 200, body: body)
    assert_kind_of Array, r.data
    assert_equal 2, r.data.size
  end

  # --- to_s / inspect ---

  def test_to_s_includes_status
    r = make_response(status: 200)
    assert_includes r.to_s, "200"
  end

  def test_inspect_same_as_to_s
    r = make_response(status: 404)
    assert_equal r.to_s, r.inspect
  end
end

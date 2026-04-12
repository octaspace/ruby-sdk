# frozen_string_literal: true

require "securerandom"

module Playground
  class BaseController < ApplicationController
    before_action :initialize_request_log

    private

    def initialize_request_log
      session.delete(:playground_request_log)
      @request_log_key = playground_request_log_key
      @request_log = Array(playground_request_log_store[@request_log_key])
    end

    def capture_api_call(label: nil, method: "GET", path: nil)
      started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      response = yield
      log_request(
        label:,
        method:,
        path: path,
        status: response.status,
        duration_ms: duration_ms(started_at)
      )
      response
    rescue OctaSpace::Error => e
      log_request(
        label:,
        method:,
        path: path,
        status: e.status || "ERR",
        duration_ms: duration_ms(started_at),
        error: e.message
      )
      e
    end

    def duration_ms(started_at)
      ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at) * 1000).round
    end

    def log_request(label:, method:, path:, status:, duration_ms:, error: nil)
      @request_log << {
        "label" => label,
        "method" => method,
        "path" => path,
        "status" => status,
        "duration_ms" => duration_ms,
        "timestamp" => Time.current.iso8601,
        "error" => error
      }

      playground_request_log_mutex.synchronize do
        playground_request_log_store[@request_log_key] = @request_log.last(100)
      end
    end

    def clear_request_log!
      playground_request_log_mutex.synchronize do
        playground_request_log_store.delete(@request_log_key)
      end
    end

    def playground_request_log_key
      session[:playground_request_log_token] ||= SecureRandom.hex(12)
    end

    def playground_request_log_store
      Rails.application.config.x.playground_request_logs ||= {}
    end

    def playground_request_log_mutex
      Rails.application.config.x.playground_request_log_mutex ||= Mutex.new
    end
  end
end

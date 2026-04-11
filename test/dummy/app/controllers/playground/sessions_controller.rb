# frozen_string_literal: true

module Playground
  class SessionsController < ApplicationController
    def index
      @sessions = octa_client.sessions.list
    rescue OctaSpace::Error => e
      @error = "API error: #{e.message}"
    end
  end
end

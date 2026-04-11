# frozen_string_literal: true

class ApplicationController < ActionController::Base
  private

  def octa_client
    @octa_client ||= OctaSpace.client
  end
  helper_method :octa_client
end

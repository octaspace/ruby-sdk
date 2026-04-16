# frozen_string_literal: true

module Playground
  class ServicesController < BaseController
    def show
      @active_tab = params[:tab].presence_in(%w[mr render vpn]) || "mr"
      @mr_catalog = capture_api_call(label: "octa_client.services.mr.list", path: "/services/mr") { octa_client.services.mr.list }
      @render_catalog = capture_api_call(label: "octa_client.services.render.list", path: "/services/render") { octa_client.services.render.list }
      @vpn_catalog = capture_api_call(label: "octa_client.services.vpn.list", path: "/services/vpn") { octa_client.services.vpn.list }
    end
  end
end

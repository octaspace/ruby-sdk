# frozen_string_literal: true

Rails.application.routes.draw do
  scope path: "playground", as: "playground", module: "playground" do
    get "dashboard", to: "dashboard#show"
    get "network", to: "network#show"
    get "account", to: "accounts#show"
    get "apps", to: "apps#show"
    get "nodes", to: "nodes#index"
    get "nodes/:id", to: "nodes#show", as: :node
    get "sessions", to: "sessions#index"
    post "sessions/stop", to: "sessions#stop", as: :sessions_stop
    get "services", to: "services#show"
    get "idle-jobs", to: "idle_jobs#show", as: :idle_jobs
    get "diagnostics", to: "diagnostics#show"
    post "diagnostics/run", to: "diagnostics#run", as: :diagnostics_run
    post "diagnostics/smoke", to: "diagnostics#smoke", as: :diagnostics_smoke
    patch "settings", to: "settings#update", as: :settings
    delete "settings", to: "settings#destroy"
    delete "request-log", to: "request_logs#destroy", as: :request_log
  end

  root to: redirect("/playground/dashboard")
end

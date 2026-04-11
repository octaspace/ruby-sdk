# frozen_string_literal: true

Rails.application.routes.draw do
  namespace :playground do
    resource  :account,     only: :show
    resources :nodes,       only: :index
    resources :sessions,    only: :index
    resource  :diagnostics, only: :show
  end

  root to: redirect("/playground/account")
end

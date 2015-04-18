Cenit::Application.routes.draw do
  mount RailsAdmin::Engine => '/data', as: 'rails_admin'
  root to: 'rails_admin/main#dashboard'

  get 'schema', to: 'schema#index'
  get '/file/:model/:field/:id/:file', to: 'file#index'

  get 'explore/:api', to: 'api#explore', as: :explore_api
  devise_for :users, controllers: { omniauth_callbacks: "users/omniauth_callbacks" } do
    get 'sign_out', to: 'users/sessions#destroy', as: :destroy_user_session
  end

  namespace :cenit do
    post '/', to: 'api#consume', as: 'api'
  end

  namespace :setup do
    resources :connections
    resources :flows
    resources :webhooks
    resources :data_types
    resources :events
    resources :connection_roles
    resources :libraries
    resources :collections
    resources :schemas
    resources :schedules
  end
end

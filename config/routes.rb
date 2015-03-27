Cenit::Application.routes.draw do

    mount RailsAdmin::Engine => '/data', as: 'rails_admin'

    get 'schema', to: 'schema#index'
    get 'file', to: 'file#index'

    get 'explore/:api' => 'api#explore', :as => :explore_api
    devise_for :users, :controllers => { :omniauth_callbacks => "users/omniauth_callbacks" } do
      get 'sign_out', :to => 'users/sessions#destroy', :as => :destroy_user_session
    end
    #devise_for :users

    #root :to => "home#index"

    root to: 'rails_admin/main#dashboard'

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

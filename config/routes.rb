Cenit::Application.routes.draw do
  scope '/hub' do
    mount RailsAdmin::Engine => '/data', as: 'rails_admin'
  
    get 'schema', to: 'schema#index'
    
    get 'explore/:api' => 'api#explore', :as => :explore_api
    devise_for :users, :controllers => { :omniauth_callbacks => "users/omniauth_callbacks" }
    
    root :to => "home#index"

    #root to: 'rails_admin/main#dashboard'

    namespace :cenit do
      post '/', to: 'api#consume', as: 'api'
    end

    namespace :setup do
      resources :connections
      resources :flows
      resources :webhooks
      resources :data_types

      post '/load', to: 'load#consume', as: 'load'
    end
    
  end
end

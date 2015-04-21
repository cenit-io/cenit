Cenit::Application.routes.draw do

    mount RailsAdmin::Engine => '/data', as: 'rails_admin'

    get 'schema', to: 'schema#index'
    match '/file/:model/:field/:id/:file' => 'file#index', via: :get

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
      #resources :api 
      get '/:model', to: 'api#index'
      get '/:model/:id', to: 'api#show'
      post '/:model', to: 'api#create'
      match '/:model/:id', to: 'api#update', via: [:patch, :put]
      delete '/:model/:id', to: 'api#destroy'
    end

end

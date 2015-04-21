Cenit::Application.routes.draw do

  mount RailsAdmin::Engine => '/data', as: 'rails_admin'

  root to: 'rails_admin/main#dashboard'
  # root to: 'home#index'

  get 'schema', to: 'schema#index'
  get '/file/:model/:field/:id/:file', to: 'file#index'

  get 'explore/:api', to: 'api#explore', as: :explore_api
  post 'write/:api', to: 'api#write', as: :write_api
  
  devise_for :users, controllers: { omniauth_callbacks: "users/omniauth_callbacks" } do
    get 'sign_out', to: 'users/sessions#destroy', as: :destroy_user_session
  end

  namespace :cenit do
    post '/', to: 'api#consume', as: 'api'
  end

  namespace :setup do
    get '/:model', to: 'api#index'
    get '/:model/:id', to: 'api#show'
    post '/:model', to: 'api#create'
    match '/:model/:id', to: 'api#update', via: [:patch, :put]
    delete '/:model/:id', to: 'api#destroy'
  end
end

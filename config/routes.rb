Cenit::Application.routes.draw do
  mount RailsAdmin::Engine => '/data', as: 'rails_admin'

  root to: 'rails_admin/main#dashboard'
  # root to: 'home#index'

  get 'explore/:api', to: 'api#explore', as: :explore_api
  post 'write/:api', to: 'api#write', as: :write_api

  devise_for :users, controllers: {omniauth_callbacks: "users/omniauth_callbacks"} do
    get 'sign_out', to: 'users/sessions#destroy', as: :destroy_user_session
  end

  get 'oauth2/callback', to: 'oauth2_callback#index'
  get 'schema', to: 'schema#index'
  get 'captcha', to: 'captcha#index'
  get 'captcha/:token', to: 'captcha#index'
  get '/file/:model/:field/:id/:file', to: 'file#index'

  namespace :api do
    namespace :v1 do
      get  '/public/:model/:api_name/:api_version/*path', to: 'api#raml'
      post '/setup/account', to: 'api#new_account'
      post '/:library/push', to: 'api#push'
      post '/:library/:model', to: 'api#push'
      get '/:library/:model', to: 'api#index'
      get '/:library/:model/:id', to: 'api#show'
      get '/:library/:model/:id/:field', to: 'api#content'
      delete '/:library/:model/:id', to: 'api#destroy'
      post '/:library/:model/:id/pull', to: 'api#pull'
      post '/:library/:model/:id/run', to: 'api#run'
      post '/auth', to: 'api#auth'
      match '/*path', to: 'api#cors_check', via: [:options]
     end
  end
end

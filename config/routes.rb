Cenit::Application.routes.draw do
  use_doorkeeper
  mount RailsAdmin::Engine => '/data', as: 'rails_admin'
  use_doorkeeper
  root to: 'rails_admin/main#dashboard'

  get 'explore/:api', to: 'api#explore', as: :explore_api
  post 'write/:api', to: 'api#write', as: :write_api
  
  devise_for :users, controllers: { omniauth_callbacks: "users/omniauth_callbacks" } do
    get 'sign_out', to: 'users/sessions#destroy', as: :destroy_user_session
  end

  get 'oauth/callback', to: 'oauth2_callback#index'
  get 'oauth2/callback', to: 'oauth2_callback#index'
  get 'schema', to: 'schema#index'
  get 'captcha', to: 'captcha#index'
  get 'captcha/:token', to: 'captcha#index'
  get '/file/:model/:field/:id/*file(.:format)', to: 'file#index'

  namespace :api do
    namespace :v1 do
      post '/auth/ping', to: 'api#auth'
      get  '/public/:model', to: 'api#index', library: 'setup'
      get  '/public/:model/:id(.:format)', to: 'api#show', library: 'setup', defaults: { format: 'json' }, constraints: {format: /(json)/}
      # get  '/public/:model/:id(.:format)', to: 'api#raml_zip', library: 'setup', constraints: {format: /(zip)/}
      # get  '/public/:model/:id/*path(.:format)', to: 'api#raml', library: 'setup', defaults: { format: 'raml' }
      # get  '/public/:model/:api_name/:api_version/*path(.:format)', to: 'api#raml', library: 'setup', defaults: { format: 'raml' }, :constraints => {:api_version => /[.]+/}
      post '/setup/account', to: 'api#new_account'
      post '/:library/push', to: 'api#push'
      post '/:library/:model', to: 'api#new'
      get '/:library/:model', to: 'api#index', defaults: { format: 'json' }
      get '/:library/:model/:id', to: 'api#show', defaults: { format: 'json' }
      get '/:library/:model/:id/:view', to: 'api#content', defaults: { format: 'json' }
      delete '/:library/:model/:id', to: 'api#destroy'
      post '/:library/:model/:id/pull', to: 'api#pull'
      post '/:library/:model/:id/run', to: 'api#run'
      match '/auth', to: 'api#auth', via: [:head]
      match '/*path', to: 'api#cors_check', via: [:options]
     end
  end

  get '/data/:model_name/*id', to: 'rails_admin/main#show'
end

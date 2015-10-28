Cenit::Application.routes.draw do
  mount RailsAdmin::Engine => '/data', as: 'rails_admin'

  root to: 'rails_admin/main#dashboard'
  # root to: 'home#index'

  get 'explore/:api', to: 'api#explore', as: :explore_api
  post 'write/:api', to: 'api#write', as: :write_api
  
  devise_for :users, controllers: { omniauth_callbacks: "users/omniauth_callbacks" } do
    get 'sign_out', to: 'users/sessions#destroy', as: :destroy_user_session
  end

  get 'oauth2/callback', to: 'oauth2_callback#index'
  get 'schema', to: 'schema#index'
  get 'captcha', to: 'captcha#index'
  get 'captcha/:token', to: 'captcha#index'
  get '/file/:model/:field/:id/:file', to: 'file#index'

  namespace :api do
    namespace :v1 do
      get  '/public/:model', to: 'api#index', library: 'setup'
      get  '/public/:model/:id(.:format)', to: 'api#show', library: 'setup', defaults: { format: 'json' }, constraints: {format: /(json)/}
      get  '/public/:model/:id(.:format)', to: 'api#raml_zip', library: 'setup', constraints: {format: /(zip)/}
      get  '/public/:model/:id/*path(.:format)', to: 'api#raml', library: 'setup', defaults: { format: 'raml' }
      #get  '/public/:model/:api_name/:api_version/*path(.:format)', to: 'api#raml', library: 'setup', defaults: { format: 'raml' }, :constraints => {:api_version => /[.]+/}
      post '/setup/account', to: 'api#new_account'
      post '/:library/push', to: 'api#push'
      post '/:library/:model', to: 'api#create'
      get '/:library/:model', to: 'api#index', defaults: { format: 'json' }
      get '/:library/:model/:id', to: 'api#show', defaults: { format: 'json' }
      get '/:library/:model/:id/:view', to: 'api#content', defaults: { format: 'json' }
      delete '/:library/:model/:id', to: 'api#destroy'
      post '/:library/:model/:id/pull', to: 'api#pull'
      post '/:library/:model/:id/run', to: 'api#run'
      post '/auth', to: 'api#auth'
      match '/*path', to: 'api#cors_check', via: [:options]
     end
  end
end

Cenit::Application.routes.draw do

  devise_for :users, controllers: {
    sessions: 'sessions',
    registrations: 'registrations'
  } do
    get 'sign_out', to: 'users/sessions#destroy', as: :destroy_user_session
  end

  root to: 'rails_admin/main#dashboard'
  get ':group/dashboard', to: 'rails_admin/main#dashboard', as: :dashboard_group
  get 'dashboard', to: 'rails_admin/main#dashboard'

  get 'explore/:api', to: 'api#explore', as: :explore_api
  post 'write/:api', to: 'api#write', as: :write_api

  service_path =
    if Cenit.service_path.present?
      "/#{Cenit.service_path}".squeeze('/')
    else
      '/service'
    end
  Cenit.service_path service_path
  if Cenit.service_url.present?
    Cenit.routed_service_url(Cenit.service_url)
  else
    mount Cenit::Service::Engine => service_path
    Cenit.routed_service_url(Cenit.homepage + service_path)
  end


  oauth_path =
    if Cenit.oauth_path.present?
      "/#{Cenit.oauth_path}".squeeze('/')
    else
      '/oauth'
    end
  Cenit.oauth_path oauth_path

  match "#{oauth_path}/authorize", to: 'oauth#index', via: [:get, :post]
  get "#{oauth_path}/callback", to: 'oauth#callback'
  if Cenit.oauth_token_end_point.to_s.to_sym == :embedded
    mount Cenit::Oauth::Engine => oauth_path
  end

  get 'captcha', to: 'captcha#index'
  get 'captcha/:token', to: 'captcha#index'
  get '/file/:model/:field/:id', to: 'file#index'
  get '/file/:model/:field/:id/*file(.:format)', to: 'file#index'

  namespace :api do
    namespace :v1 do
      post '/auth/ping', to: 'api#auth'
      get '/public/:model', to: 'api#index', ns: 'setup'
      get '/public/:model/:id(.:format)', to: 'api#show', ns: 'setup', defaults: { format: 'json' }, constraints: { format: /(json)/ }
      post '/setup/user', to: 'api#new_user'
      post '/:ns/push', to: 'api#push'
      post '/:ns/:model', to: 'api#new'
      get '/:ns/:model', to: 'api#index', defaults: { format: 'json' }
      get '/:ns/:model/:id', to: 'api#show', defaults: { format: 'json' }
      get '/:ns/:model/:id/:view', to: 'api#content', defaults: { format: 'json' }
      delete '/:ns/:model/:id', to: 'api#destroy'
      post '/:ns/:model/:id/pull', to: 'api#pull'
      post '/:ns/:model/:id/run', to: 'api#run'
      match '/auth', to: 'api#auth', via: [:head]
      match '/*path', to: 'api#cors_check', via: [:options]
    end

    namespace :v2 do
      post '/auth/ping', to: 'api#auth'
      get '/public/:model', to: 'api#index', ns: 'setup'
      get '/public/:model/:id(.:format)', to: 'api#show', ns: 'setup', defaults: { format: 'json' }, constraints: { format: /(json)/ }
      post '/setup/user', to: 'api#new_user'
      post '/:ns/push', to: 'api#push'
      post '/:ns/:model', to: 'api#new'
      get '/:ns/:model', to: 'api#index', defaults: { format: 'json' }
      get '/:ns/:model/:id', to: 'api#show', defaults: { format: 'json' }
      post '/:ns/:model/:id', to: 'api#update'
      delete '/:ns/:model/:id', to: 'api#destroy'
      post '/:ns/:model/:id/pull', to: 'api#pull'
      post '/:ns/:model/:id/run', to: 'api#run'
      get '/:ns/:model/:id/retry', to: 'api#retry'
      get '/:ns/:model/:id/:view', to: 'api#content', defaults: { format: 'json' }
      match '/auth', to: 'api#auth', via: [:head]
      match '/*path', to: 'api#cors_check', via: [:options]
    end

    namespace :v3 do
      post '/setup/user', to: 'api#new_user'
      post '/:ns/push', to: 'api#push'
      post '/:ns/:model', to: 'api#new'
      get '/:ns/:model', to: 'api#index', defaults: { format: 'json' }
      get '/:ns/:model/:id', to: 'api#show', defaults: { format: 'json' }
      post '/:ns/:model/:id', to: 'api#update'
      delete '/:ns/:model/:id', to: 'api#destroy'
      match '/*path', to: 'api#cors_check', via: [:options]
    end
  end

  match 'app/:id_or_ns' => 'app#index', via: [:all]
  match 'app/:id_or_ns/:app_slug' => 'app#index', via: [:all]
  match 'app/:id_or_ns/:app_slug/*path' => 'app#index', via: [:all]

  get 'remote_shared_collection/:id', to: 'rails_admin/main#remote_shared_collection'
  get 'remote_shared_collection/:id/pull', to: 'rails_admin/main#remote_shared_collection'
  mount RailsAdmin::Engine => '/', as: 'rails_admin'

  match '/:model_name/:id/swagger/*path' => 'rails_admin/main#swagger', via: [:all]

  get '/:model_name/*id', to: 'rails_admin/main#show'

  namespace :contact_us do
    controller :contacts do
      post '/contacts' => :create
    end
  end


end

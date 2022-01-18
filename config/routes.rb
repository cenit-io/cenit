Cenit::BuildInApps.build_controllers_from(BuildInAppBaseController)

Cenit::Application.routes.draw do
  devise_for :users, controllers: {
    sessions: 'sessions',
    registrations: 'registrations',
    confirmations: 'confirmations'
  } do
    get 'sign_out', to: 'users/sessions#destroy', as: :destroy_user_session
  end

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
  post "#{oauth_path}/token", to: 'oauth#token'
  match "#{oauth_path}/*path", to: 'oauth#cors_check', via: [:options]

  get '/authorization/:tenant_id/:id', to: 'authorization#show', as: 'authorization_show'
  get '/authorization/:tenant_id/:id/authorize', to: 'authorization#authorize', as: 'authorization_authorize'

  get 'captcha', to: 'captcha#index'
  get 'captcha/:token', to: 'captcha#index'
  get '/file/:tenant_id/:model/:id/:field', to: 'file#index'
  get '/file/:tenant_id/:model/:id/:field/*file', to: 'file#index'
  match '/file/:tenant_id/:model/:id/:field/*file', to: 'file#cors_check', via: [:options]
  get 'public/:tenant_id/:data_type_id/:file_id', to: 'file#public'
  match 'public/:tenant_id/:data_type_id/:file_id', to: 'file#cors_check', via: [:options]

  post 'hook/:slug', to: 'hook#digest'
  post 'hook/:slug/:access_token', to: 'hook#digest'

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
      post '/:ns/:model/digest', to: 'api#data_type_digest'
      get '/:ns/:model', to: 'api#index', defaults: { format: 'json' }
      get '/:ns/:model/:id', to: 'api#show', defaults: { format: 'json' }
      post '/:ns/:model/:id', to: 'api#update'
      delete '/:ns/:model/:id', to: 'api#destroy'
      post '/:ns/:model/:id/pull', to: 'api#pull'
      post '/:ns/:model/:id/run', to: 'api#run'
      get '/:ns/:model/:id/retry', to: 'api#retry'
      get '/:ns/:model/:id/authorize', to: 'api#authorize'
      get '/:ns/:model/:id/:view', to: 'api#content', defaults: { format: 'json' }
      match '/auth', to: 'api#auth', via: [:head]
      match '/*path', to: 'api#cors_check', via: [:options]
    end

    namespace :v3 do
      post '/setup/user', to: 'api#new_user'
      post '/:__ns_/:__model_', to: 'api#new'
      get '/:__ns_/:__model_', to: 'api#index', defaults: { format: 'json' }
      get '/:__ns_/:__model_/:__id_', to: 'api#show', defaults: { format: 'json' }
      post '/:__ns_/:__model_/:__id_', to: 'api#update'
      match '/:__ns_/:__model_/:__id_/digest', to: 'api#digest', via: [:get, :post, :delete]
      match '/:__ns_/:__model_/:__id_/digest/*_digest_path', to: 'api#digest', via: [:get, :post, :delete]
      delete '/:__ns_/:__model_/:__id_', to: 'api#destroy'
      match '/*path', to: 'api#cors_check', via: [:options]
    end
  end

  Cenit::BuildInApps.controllers.each do |key, controller|
    match "/app/#{key}/*path", to: "#{controller.app_module.controller_prefix}/main#cors_check", via: [:options]
    controller.routes.each do |route|
      method, path, options = route
      match "/app/#{key}/#{path}".squeeze('/'), to: "#{controller.app_module.controller_prefix}/main##{options[:to]}", via: method
    end
    get "/app/#{key}".squeeze('/'), to: 'application#index'
  end

  match '/app/*path', to: 'app#cors_check', via: [:options]
  match 'app/:id_or_ns' => 'app#index', via: ::Setup::Webhook::SYM_METHODS
  match 'app/:id_or_ns/:app_slug' => 'app#index', via: ::Setup::Webhook::SYM_METHODS
  match 'app/:id_or_ns/:app_slug/*path' => 'app#index', via: ::Setup::Webhook::SYM_METHODS

  namespace :contact_us do
    controller :contacts do
      post '/contacts' => :create
      get :thanks
    end
  end

  Cenit.options.keys.grep(/:route:draw:listener\Z/).each do |source_key|
    if (listener = Cenit[source_key]).is_a?(String)
      listener =
        begin
          Cenit[source_key].constantize
        rescue
          nil
        end
    end
    listener && listener.try(:on_route_draw, self)
  end

  root_app_module =
    begin
      ENV['ROOT_APP'].constantize
    rescue
      nil
    end

  if root_app_module
    root to: "#{root_app_module.controller_prefix}/main#index"
  else
    root to: 'application#index'
  end
end

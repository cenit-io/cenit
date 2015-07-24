Cenit::Application.routes.draw do
  mount RailsAdmin::Engine => '/data', as: 'rails_admin'

  root to: 'rails_admin/main#dashboard'
  # root to: 'home#index'

  get 'explore/:api', to: 'api#explore', as: :explore_api
  post 'write/:api', to: 'api#write', as: :write_api
  
  devise_for :users, controllers: { omniauth_callbacks: "users/omniauth_callbacks" } do
    get 'sign_out', to: 'users/sessions#destroy', as: :destroy_user_session
  end

  get 'schema', to: 'schema#index'
  get 'captcha', to: 'captcha#index'
  get 'captcha/:token', to: 'captcha#index'

  namespace :api do
    namespace :v1 do
      post '/setup/account', to: 'api#new_account'
      post '/:library/push', to: 'api#push'
      get '/:library/:model', to: 'api#index'
      get '/:library/:model/:id', to: 'api#show'
      delete '/:library/:model/:id', to: 'api#destroy'
      post '/:library/:model/:id/pull', to: 'api#pull'
      post '/:library/:model/:id/execute', to: 'api#execute'
      post '/auth', to: 'api#auth'
    end
  end
end

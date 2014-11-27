Cenit::Application.routes.draw do
  devise_for :users
  #root :to => "visitors#index"

  mount RailsAdmin::Engine => '/data', as: 'rails_admin'
  
  root to: 'rails_admin/main#dashboard'

  namespace :cenit do
    post '/', to: 'api#consume', as: 'api'
  end
  
  namespace :setup do
    resources :connections
    resources :flows
    resources :webhooks
    resources :data_types
  end  

end

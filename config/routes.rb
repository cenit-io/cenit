Cenit::Application.routes.draw do

  devise_for :users
  root :to => "visitors#index"

  mount RailsAdmin::Engine => '/data', as: 'rails_admin'
  
  namespace :dashboard do
    get '/overview/index', to: 'overview#index', as: 'overview'
    get '/overview/orders_statistics', to: 'overview#orders_statistics', as: 'orders_statistics'
    get '/overview/revenues_statistics', to: 'overview#revenues_statistics', as: 'revenues_statistics'
    get '/overview/overview_statistics', to: 'overview#overview_statistics', as: 'overview_statistics'
  end

  namespace :cenit do
    post '/', to: 'webhook#consume', as: 'webhook'
  end

end

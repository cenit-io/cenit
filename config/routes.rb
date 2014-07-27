Cenit::Application.routes.draw do

  devise_for :users
  root :to => "visitors#index"

  mount RailsAdmin::Engine => '/data', as: 'rails_admin'
  
  namespace :dashboard do
    get '/overview', to: 'overview#index', as: 'overview'
  end

  namespace :cenit do
    post '/', to: 'webhook#consume', as: 'webhook'
  end

end

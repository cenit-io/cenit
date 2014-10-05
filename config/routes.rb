Cenit::Application.routes.draw do
  devise_for :users
  root :to => "visitors#index"

  mount RailsAdmin::Engine => '/data', as: 'rails_admin'
  
  #root to: 'rails_admin/main#dashboard'

  namespace :cenit do
    post '/', to: 'webhook#consume', as: 'webhook'
  end

end

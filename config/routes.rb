Cenit::Application.routes.draw do

  mount RailsAdmin::Engine => '/data', as: 'rails_admin'
  namespace :cenit do
    post '/', to: 'webhook#consume', as: 'webhook'
  end

end

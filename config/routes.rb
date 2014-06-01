Cenit::Application.routes.draw do

  namespace :hub do
    post '*path', to: 'webhook#consume', as: 'webhook'
  end

  resources :posts do
    resources :comments
  end

end

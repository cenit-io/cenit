Cenit::Application.routes.draw do

  devise_for :users
  root :to => "visitors#index"

  mount RailsAdmin::Engine => '/data', as: 'rails_admin'
  
  namespace :dashboard do
    
    get '/overview', to: 'overview#index', as: 'overview'
    
    namespace :sales do
      ['sources','revenues','transactions','items','adjustments','taxes','shipments'].each do |resource|
        get "/#{resource}", to: "#{resource}#index", as: "#{resource}"   
        get "/#{resource}/by-week-days", to: "#{resource}#by_week_days", as: "#{resource}_by_week_days"
        get "/#{resource}/by-hours", to: "#{resource}#by_hours", as: "#{resource}_by_hours"    
      end  
    end
      
  end

  namespace :cenit do
    post '/', to: 'webhook#consume', as: 'webhook'
  end

end

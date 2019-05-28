module Cenit
  ApplicationParameter.class_eval do
    include RailsAdmin::Models::Cenit::ApplicationParameterAdmin
  end
end

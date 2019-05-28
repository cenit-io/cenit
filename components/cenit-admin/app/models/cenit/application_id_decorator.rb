module Cenit
  ApplicationId.class_eval do
    include RailsAdmin::Models::Cenit::ApplicationIdAdmin
  end
end

module Cenit
  BasicTenantToken.class_eval do
    include RailsAdmin::Models::Cenit::BasicTokenAdmin
  end
end

module Cenit
  OauthAccessGrant.class_eval do
    include RailsAdmin::Models::Cenit::OauthAccessGrantAdmin
  end
end

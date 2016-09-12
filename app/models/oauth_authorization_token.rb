class OauthAuthorizationToken < Cenit::BasicToken
  include Cenit::TenantToken

  belongs_to :application, class_name: Setup::Application.to_s, inverse_of: nil
  belongs_to :authorization, class_name: Setup::BaseOauthAuthorization.to_s, inverse_of: nil
end
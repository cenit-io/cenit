class CallbackAuthorizationToken < Cenit::BasicToken
  include Cenit::TenantToken

  belongs_to :app_id, class_name: Cenit::ApplicationId.to_s, inverse_of: nil
  belongs_to :authorization, class_name: Setup::Authorization.to_s, inverse_of: nil
end
module OauthTokenCommon
  extend ActiveSupport::Concern

  include Cenit::TenantToken

  included do
    token_length 60

    default_token_span 1.hour
  end
end
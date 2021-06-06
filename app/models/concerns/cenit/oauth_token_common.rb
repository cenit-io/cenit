module Cenit
  module OauthTokenCommon
    extend ActiveSupport::Concern

    include Cenit::TenantToken

    included do
      belongs_to :user, class_name: Cenit::MultiTenancy.user_model_name, inverse_of: nil

      token_length Cenit.default_oauth_token_length

      default_token_span 1.hour
    end
  end
end
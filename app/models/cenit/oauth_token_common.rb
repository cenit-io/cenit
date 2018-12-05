module Cenit
  module OauthTokenCommon
    extend ActiveSupport::Concern

    include Cenit::TenantToken

    included do

      field :user_id

      token_length 60

      default_token_span 1.hour
    end
  end
end
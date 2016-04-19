module OauthTokenCommon
  extend ActiveSupport::Concern

  include AccountTokenCommon

  included do
    token_length 60

    default_token_span 1.hour
  end
end
class OauthAuthorizationToken < CenitToken
  include AccountTokenCommon

  belongs_to :authorization, class_name: Setup::BaseOauthAuthorization.to_s, inverse_of: nil
end
class OauthCodeToken < CenitToken
  include OauthTokenCommon

  field :scope, type: String
end
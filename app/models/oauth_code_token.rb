class OauthCodeToken < Cenit::BasicToken
  include OauthTokenCommon

  field :scope, type: String
end
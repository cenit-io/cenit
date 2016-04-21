class OauthAccessToken < CenitToken
  include OauthGrantToken

  field :token_type, type: Symbol, default: :Bearer

  validates_inclusion_of :token_type, in: [:Bearer]
end
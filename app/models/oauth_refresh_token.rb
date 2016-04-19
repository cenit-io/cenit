class OauthRefreshToken < CenitToken
  include OauthGrantToken

  default_token_span :never

end
module Cenit
  class OauthRefreshToken < Cenit::BasicToken
    include OauthGrantToken

    default_token_span :never

  end
end
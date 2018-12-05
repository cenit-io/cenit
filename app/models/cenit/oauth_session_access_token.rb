
module Cenit
  # = OauthSessionAccessToken
  #
  # Store session token for OAuth 2.0 access.
  class OauthSessionAccessToken < OauthAccessToken

    def hit
      update(expires_at: Time.now + self.class.default_token_span)
    end
  end
end

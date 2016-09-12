class OauthAccessToken < Cenit::BasicToken
  include OauthGrantToken

  field :token_type, type: Symbol, default: :Bearer

  validates_inclusion_of :token_type, in: [:Bearer]

  class << self
    def for(user, app_id, scope)
      account = Account.current || user.account
      scope = Cenit::Scope.new(scope) unless scope.is_a?(Cenit::Scope)
      unless (access_grant = Setup::OauthAccessGrant.with(account).where(application_id: app_id).first)
        access_grant = Setup::OauthAccessGrant.with(account).new(application_id: app_id)
      end
      access_grant.scope = scope.to_s
      access_grant.save
      token = OauthAccessToken.create(account: account, application_id: app_id)
      access =
        {
          access_token: token.token,
          token_type: token.token_type,
          created_at: token.created_at.to_i,
          token_span: token.token_span
        }
      if scope.offline_access? &&
        OauthRefreshToken.where(account: account, application_id: app_id).blank?
        refresh_token = OauthRefreshToken.create(account: account, application_id: app_id)
        access[:refresh_token] = refresh_token.token
      end
      if scope.openid?
        payload =
          {
            iss: Cenit.homepage,
            sub: user.id.to_s,
            aud: app_id.identifier,
            exp: access[:created_at] + access[:token_span],
            iat: access[:created_at],
          }
        if scope.email? || scope.profile? #TODO Include other OpenID scopes
          payload[:email] = user.email
          payload[:email_verified] = user.confirmed_at.present?
          if scope.profile?
            payload[:given_name] = user.name
            #TODO Family Name for Cenit Users
            # payload[:family_name] = user.family_name
          end
        end
        access[:id_token] = JWT.encode(payload, nil, 'none')
      end
      access
    end
  end
end
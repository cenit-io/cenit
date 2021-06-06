require 'jwt'

module Cenit
  # = OauthAccessToken
  #
  # Store token for OAuth 2.0 access.
  class OauthAccessToken < BasicToken
    include OauthGrantToken

    field :token_type, type: StringifiedSymbol, default: :Bearer

    validates_inclusion_of :token_type, in: [:Bearer]

    def hit
      # Nothing here
    end

    def get_tenant
      (access_grant&.origin == :owner &&
        (user&.account || tenant&.owner&.account)) || super
    end

    class << self
      def for(app_id, scope, user_or_id, tenant = Cenit::MultiTenancy.tenant_model.current)
        user_model = Cenit::MultiTenancy.user_model
        user =
          if user_model && user_or_id.is_a?(user_model)
            user_or_id
          else
            (user_model && user_model.where(id: user_or_id).first) || user_or_id
          end
        scope = Cenit::OauthScope.new(scope) unless scope.is_a?(Cenit::OauthScope)
        access_grant = tenant.switch { Cenit::OauthAccessGrant.where(application_id: app_id).first } ||
          tenant.switch { Cenit::OauthAccessGrant.new(application_id: app_id) }
        access_grant.scope = Cenit::OauthScope.new(access_grant.scope).merge(scope).to_s
        access_grant.save
        token =
          if scope.session_access?
            Cenit::OauthSessionAccessToken
          else
            self
          end.create(tenant: tenant, application_id: app_id, user_id: user.id)
        access =
          {
            access_token: token.token,
            token_type: token.token_type,
            created_at: token.created_at.to_i,
            expires_in: token.token_span
          }
        if scope.offline_access? &&
          Cenit::OauthRefreshToken.where(tenant: tenant, application_id: app_id, user_id: user.id).blank?
          refresh_token = Cenit::OauthRefreshToken.create(tenant: tenant, application_id: app_id, user_id: user.id)
          access[:refresh_token] = refresh_token.token
        end
        if scope.openid?
          payload =
            {
              iss: Cenit.homepage,
              sub: user.id.to_s,
              aud: app_id.identifier,
              exp: access[:created_at] + access[:expires_in],
              iat: access[:created_at]
            }
          payload_inspector = proc do |property, key|
            key ||= property
            if user.respond_to?(property) && (field_value = user.send(property))
              payload[key] = field_value
            end
          end
          # TODO: Include other OpenID scopes
          payload_inspector.call(:email) if scope.email? && (app_id.trusted? || user.confirmed?)
          if scope.profile?
            [
              :name,
              :given_name,
              :family_name,
              :middle_name
            ].each { |property| payload_inspector.call(property) }
            payload_inspector.call(:picture_url, :picture)
          end
          access[:id_token] = JWT.encode(payload, nil, 'none')
        end
        access
      end
    end
  end
end

module Setup
  class AppAuthorization < Setup::Oauth2Authorization
    include CenitScoped
    include RailsAdmin::Models::Setup::AppAuthorizationAdmin

    build_in_data_type.with(:namespace, :name, :provider, :client, :parameters, :template_parameters, :scopes)
    build_in_data_type.referenced_by(:namespace, :name)

    def check
      errors.add(:client, 'must be an App') unless client.is_a?(Setup::Application)
      super
    end

    def ready_to_save?
      true
    end

    def request_token(callback_params)
      fail 'Invalid authorization code' unless (token = Cenit::OauthCodeToken.where(token: callback_params[:code]).first)
      application_id = client.application_id
      access = token.tenant.switch do
        Cenit::OauthAccessToken.for(application_id, token.scope, token.user_id, token.tenant)
      end
      token.destroy
      self.token_type = access[:token_type]
      self.authorized_at = Time.at(access[:created_at].to_i)
      self.access_token = access[:access_token]
      self.token_span = access[:expires_in]
      self.refresh_token = access[:refresh_token] if access.key?(:refresh_token)
      self.id_token = access[:id_token]
    end

    def fresh_access_token
      if authorized_at.nil? || (authorized_at + (token_span || 0) < Time.now - 60)
        fail 'Invalid client' unless client.is_a?(Setup::Application)
        fail 'Invalid refresh token' unless (token = Cenit::OauthRefreshToken.where(token: refresh_token).first)
        fail 'Refresh token app mismatch' unless token.application_id == client.application_id
        token.set_current_tenant!
        access = Cenit::OauthAccessToken.for(client.application_id, token.scope, token.user_id, token.tenant)
        token.destroy unless token.long_term?
        update!(
          authorized_at: Time.at(access[:created_at].to_i),
          token_type: access[:token_type],
          access_token: access[:access_token],
          token_span: access[:expires_in]
        )
      end
      access_token
    end
  end
end

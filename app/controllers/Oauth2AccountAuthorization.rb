module OAuth2AccountAuthorization

  def soft_authorize_account
    authorize_account(true)
  end

  def authorize_account(soft = false)
    account_backup = Account.current
    user_backup = User.current
    Account.current = User.current = error_description = nil
    if (auth_header = request.headers['Authorization'])
      auth_header = auth_header.to_s.squeeze(' ').strip.split(' ')
      if auth_header.length == 2
        @access_token = access_token = Cenit::OauthAccessToken.where(token_type: auth_header[0], token: auth_header[1]).first
        if access_token&.alive?
          if (user = access_token.user)
            User.current = user
            if (x_tenant_id = request.headers['X-Tenant-Id'])
              if (x_tenant = Account.find_where(id: x_tenant_id).first)
                Account.current = x_tenant
              else
                error_description = 'Invalid tenant'
              end
            else
              x_tenant_id = nil
            end
            if !error_description && (x_tenant_id || access_token.set_current_tenant!)
              access_grant = Cenit::OauthAccessGrant.where(application_id: access_token.application_id).first
              if access_grant
                @oauth_scope = access_grant.oauth_scope
              else
                Account.current = nil
                error_description = 'Access grant revoked or moved outside token tenant'
              end
            end
          else
            error_description = 'The token owner is no longer an active user'
          end
        else
          error_description = 'Access token is expired or malformed'
        end
      else
        error_description = 'Malformed authorization header'
      end
      if User.current && Account.current
        @ability = Ability.new(User.current)
        true
      else
        unless error_description
          report = Setup::SystemReport.create(message: "Unable to locate tenant for authorization header #{auth_header}")
          error_description = "Ask for support by supplying this code: #{report.id}"
        end
        response.headers['WWW-Authenticate'] = %(Bearer realm="example",error="invalid_token",error_description=#{error_description})
        render json: { error: 'invalid_token', error_description: error_description }, status: :unauthorized
        false
      end
    else
      if soft
        Account.current = account_backup
        User.current = user_backup
      else
        @ability = Ability.new(nil)
      end
      true
    end
  end
end
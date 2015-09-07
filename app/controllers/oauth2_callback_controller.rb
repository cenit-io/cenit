class Oauth2CallbackController < ApplicationController

  def index
    redirect_path = rails_admin.index_path(Setup::Oauth2Authorization.to_s.underscore.gsub('/', '~'))
    error = nil
    if (code = params[:code]) &&
      (cenit_token = CenitToken.where(token: params[:state]).first) &&
      (Account.current = Account.where(id: cenit_token.data[:account_id]).first) &&
      (authorization = Setup::Oauth2Authorization.where(id: cenit_token.data[:authorization_id]).first)
      begin
        client = OAuth2::Client.new(authorization.client.identifier, authorization.client.secret, token_url: authorization.provider.token_endpoint)
        # client.connection.proxy('http://54.68.213.74:8080')
        options =
          {
            redirect_uri: "#{Cenit.oauth2_callback_site}/oauth2/callback",
            token_method: authorization.provider.access_token_request_method
          }
        token = client.auth_code.get_token(code, options)
        authorization.token_type = token.params['token_type']
        authorization.authorized_at =
          if time = token.params['created_at']
            Time.at(time)
          else
            Time.now
          end
        authorization.access_token = token.token
        authorization.token_span = token.expires_in
        authorization.refresh_token = token.refresh_token
        authorization.save
        redirect_path = rails_admin.show_path(model_name: Setup::Oauth2Authorization.to_s.underscore.gsub('/', '~'), id: authorization.id.to_s)
      rescue Exception => ex
        error = ex.message
      end
    else
      error = 'Invalid state data'
    end

    cenit_token.delete if cenit_token

    if error.present?
      error = error[1..500] + '...' if error.length > 500
      flash[:error] = error.html_safe
    end

    redirect_to redirect_path
  end
end

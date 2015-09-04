class Oauth2CallbackController < ApplicationController

  def index
    if (code = params[:code]) && state = params[:state]
      account_id, authorization_id = state.split(' ')
      if Account.current = Account.where(id: account_id).first
        if authorization = Setup::Oauth2Authorization.where(id: authorization_id).first
          begin
            client = OAuth2::Client.new(authorization.client.identifier, authorization.client.secret, site: authorization.provider.token_endpoint)
            token = client.auth_code.get_token(code, redirect_uri: "#{Cenit.oauth2_callback_site}/oauth2/callback")
            authorization.token_type = token.params['token_type']
            authorization.authorized_at = Time.at(token.params['created_at'])
            authorization.access_token = token.token
            authorization.token_span = token.expires_in
            authorization.refresh_token = token.refresh_token
            authorization.save
            redirect_to rails_admin.show_path(model_name: Setup::Oauth2Authorization.to_s.underscore.gsub('/', '~'), id: authorization.id.to_s)
          rescue Exception => ex
            render json: {error: ex.message}, status: :not_acceptable
          end
        else
          render json: {error: 'invalid state data'}, status: :not_found
        end
      else
        render json: {error: 'invalid state data'}, status: :not_found
      end
    else
      render json: {error: 'code or state missing'}, status: :bad_request
    end
  end
end

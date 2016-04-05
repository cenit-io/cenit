class Oauth2CallbackController < ApplicationController

  def index
    redirect_path = rails_admin.index_path(Setup::Authorization.to_s.underscore.gsub('/', '~'))
    error = params[:error]
    if (cenit_token = OauthAuthorizationToken.where(token: params[:state] || session[:oauth_state]).first) &&
      cenit_token.set_current_account && (authorization = cenit_token.authorization)
      begin
        redirect_path =
          if (app = cenit_token.application) && (ns = Setup::Namespace.where(name: app.namespace).first)
            "/app/#{ns.slug}/#{app.slug}/authorization/#{authorization.id}?X-User-Access-Key=#{Account.current.owner.number}&X-User-Access-Token=#{Account.current.owner.token}"
          else
            rails_admin.show_path(model_name: authorization.class.to_s.underscore.gsub('/', '~'), id: authorization.id.to_s)
          end
        if params[:code]
          params[:cenit_token] = cenit_token
          authorization.request_token!(params)
        else
          authorization.cancel!
        end
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

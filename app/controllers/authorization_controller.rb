class AuthorizationController < ApplicationController

  before_action { warden.authenticate! scope: :user }

  def authorize
    if (tenant = Tenant.where(id: params[:tenant_id]).first)
      tenant.switch do
        errors = nil
        auth = @authorization = Setup::Authorization.where(id: params[:id]).first
        if auth
          if auth.check
            if auth.is_a?(Setup::CallbackAuthorization)
              begin
                cenit_token = CallbackAuthorizationToken.create(authorization: auth, data: {})
                url = auth.authorize_url(cenit_token: cenit_token)
                cenit_token.save
                session[:oauth_state] = cenit_token.token

                redirect_to url
              rescue Exception => ex
                errors = [ex.message]
              end
            else
              render_form_for(auth)
            end
          else
            errors = auth.errors.full_messages
          end

          if errors
            @errors = errors
            render :errors, status: :unprocessable_entity
          end
        else
          render :not_found, status: :not_found
        end
      end
    else
      render :not_found, status: :not_found
    end
  end

  def show
    if (error = params[:error])
      @errors = [error]
    end
    @authorization = (tenant = Tenant.where(id: params[:tenant_id]).first) &&
      tenant.switch { Setup::Authorization.where(id: params[:id]).first }

    render :not_found, status: :not_found unless @authorization
  end

  def render_form_for(auth)
    render :form
  end
end

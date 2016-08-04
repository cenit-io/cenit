class AppController < ApplicationController

  before_action :authorize_account, :find_app

  def index
    if (path = request.path.split('/').from(@id_routing ? 3 : 4).join('/')).empty?
      path = '/'
    end
    method = request.method.to_s.downcase.to_sym
    if (action = @app.actions.detect { |a| a.method == method && a.match?(path) })
      control = Cenit::Control.new(@app, self, action)
      begin
        result = action.run(control)
        unless control.done?
          render plain: result
        end
      rescue Exception => ex
        render plain: ex.message, status: :internal_server_error
      end
    else
      render plain: "Bad path: #{path}", status: :bad_request
    end
  end

  protected

  def find_app
    found = false
    if (@id_routing && (app = @app)) ||
      ((ns = Setup::Namespace.where(slug: params[:id_or_ns]).first) &&
        (app = Setup::Application.where(namespace: ns.name, slug: params[:app_slug]).first))
      if @app.nil? || app == @app
        @app ||= app
        if @authentication_method.nil? || @app.authentication_method == @authentication_method
          found = true
        else
          render plain: 'Invalid authentication method', status: :bad_request
        end
      else
        render plain: 'Invalid application ID', status: :not_found
      end
    else
      render plain: 'App not found', status: :not_found
    end
    found
  end

  def authorize_account
    user = nil
    key = params.delete('X-User-Access-Key')
    key = request.headers['X-User-Access-Key'] || key
    token = params.delete('X-User-Access-Token')
    token = request.headers['X-User-Access-Token'] || token
    if key || token
      user = User.where(key: key).first
      if user && Devise.secure_compare(user.token, token) && user.has_role?(:admin)
        Account.current = user.account
        @authentication_method = :user_credentials
      end
    else
      key = request.headers['X-Hub-Store']
      token = request.headers['X-Hub-Access-Token']
      if key || token
        Account.set_current_with_connection(key, token)
        @authentication_method = :user_credentials
      end
    end
    if (app_id = ApplicationId.where(identifier: params[:id_or_ns]).first)
      @id_routing = true
    elsif (app_id = params[:client_id])
      app_id = ApplicationId.where(identifier: app_id).first
    end
    if app_id
      if Account.current && Account.current != app_id.account
        Account.current = nil
      else
        Account.current ||= app_id.account
        @app = Setup::Application.where(application_id: app_id).first
        @authentication_method = :application_id
      end
    end
    User.current = user || (Account.current ? Account.current.owner : nil)
    if Account.current && User.current
      true
    else
      render plain: 'Invalid credentials', status: :unauthorized
      false
    end
  end
end

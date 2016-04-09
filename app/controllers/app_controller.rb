class AppController < ApplicationController

  before_action :authorize_account, :find_app

  def index
    if (path = request.path.split('/').from(4).join('/')).empty?
      path = '/'
    end
    if (action = @app.actions.where(method: request.method.to_s.downcase).detect { |a| a.match?(path) })
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
    if (ns = Setup::Namespace.where(slug: params[:ns]).first) &&
      (@app = Setup::Application.where(namespace: ns.name, slug: params[:app_slug]).first)
      true
    else
      render plain: 'App not found', status: :not_found
      false
    end
  end

  def authorize_account
    key = params.delete('X-User-Access-Key')
    key = request.headers['X-User-Access-Key'] || key
    token = params.delete('X-User-Access-Token')
    token = request.headers['X-User-Access-Token'] || token
    if key || token
      user = User.where(key: key).first
      if user && Devise.secure_compare(user.token, token) && user.has_role?(:admin)
        Account.current = user.account
      end
    else
      key = request.headers['X-Hub-Store']
      token = request.headers['X-Hub-Access-Token']
      Account.set_current_with_connection(key, token) if key || token
    end
    User.current = user || (Account.current ? Account.current.owner : nil)
    if Account.current && User.current
      true
    else
      render plain: 'Ivalid credentials', status: :unauthorized
      false
    end
  end
end

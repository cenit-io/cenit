class AppController < ApplicationController

  before_action :authorize_account, :find_app, :find_app_control_action
  before_action :process_headers

  attr_reader :app_control

  def index
    content = @app_action.run(@app_control)
    render plain: content if @app_control && !@app_control.done?
  rescue Exception => ex
    Setup::SystemNotification.create_from(ex, "Handling action #{@app.custom_title} -> #{@app_action}")
    render plain: ex.message, status: :internal_server_error if @app_control && !@app_control.done?
  end

  def cors_check
    process_headers
    render nothing: true
  end

  protected

  def process_headers
    headers.delete('X-Frame-Options')
    headers['Access-Control-Allow-Origin'] = '*'
    headers['Access-Control-Allow-Credentials'] = false
    headers['Access-Control-Allow-Headers'] = '*'
    headers['Access-Control-Allow-Methods'] = 'GET, POST, PUT, PATCH, DELETE, OPTIONS'
    headers['Access-Control-Max-Age'] = '1728000'
  end

  def find_app_control_action
    path = request.path.split('/').from(@id_routing ? 3 : 4).join('/')
    path ||= '/' if path.blank?
    method = request.request_method.to_s.downcase.to_sym
    @app_action = @app.actions.detect { |a| a.method == method && a.match?(path) }
    @app_control = Cenit::Control.new(@app, self, @app_action) if @app_action

    unless @app_control
      render(plain: "Bad path: #{path}", status: :bad_request)
      false
    end
  end

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
    @authentication_method = nil
    user = nil

    # New key and token params.
    key = request.headers['X-Tenant-Access-Key'] || params.delete('X-Tenant-Access-Key')
    token = request.headers['X-Tenant-Access-Token'] || params.delete('X-Tenant-Access-Token')

    # Legacy key and token params.
    key ||= request.headers['X-User-Access-Key'] || params.delete('X-User-Access-Key')
    token ||= request.headers['X-User-Access-Token'] || params.delete('X-User-Access-Token')

    if key || token
      [
        User,
        Account
      ].each do |model|
        next if user
        record = model.where(key: key).first
        if record && Devise.secure_compare(record[:authentication_token], token)
          Account.current = record.api_account
          user = record.user
          @authentication_method = :user_credentials
        end
      end
    end
    unless key || token
      key = request.headers['X-Hub-Store']
      token = request.headers['X-Hub-Access-Token']
      if (key || token) && Account.set_current_with_connection(key, token)
        @authentication_method = :user_credentials
      end
    end
    app_id = nil
    [:identifier, :slug].each do |key|
      break if (app_id = Cenit::ApplicationId.where(key => params[:id_or_ns]).first)
    end
    if app_id
      @id_routing = true
    elsif (app_id = params[:client_id])
      app_id = Cenit::ApplicationId.where(identifier: app_id).first
    end
    if app_id
      if app_id.registered?
        Account.current = user = nil unless Account.current == app_id.tenant
      end
      if Account.current.nil? || Account.current == app_id.tenant
        @app = app_id.app
        @authentication_method ||=
          if Account.current
            @app.authentication_method
          else
            :application_id
          end
        Account.current ||= app_id.tenant
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

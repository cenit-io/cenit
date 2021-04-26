class ApplicationController < ActionController::Base
  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.

  protect_from_forgery with: :null_session, if: -> { request.format.json? }

  rescue_from CanCan::AccessDenied do |exception|
    if _current_user
      redirect_to main_app.root_path, alert: exception.message
    else
      redirect_to new_session_path(User)
    end
  end

  around_action :scope_current_account

  def index
    @apps =
      Cenit::BuildInApps.apps_modules
        .select(&:controller?)
        .map do |m|
        app = m.app
        {
          logo: app.configuration.logo,
          name: app.name,
          url: "app/#{m.app_key}"
        }
      end
  end

  protected

  def check_user_signed_in
    unless User.current
      redirect_to new_session_path(User, return_to: request.env['PATH_INFO'])
    end
  end

  def do_optimize
    Setup::Optimizer.save_namespaces
  end

  private

  def optimize
    do_optimize
  end

  def clean_thread_cache
    Thread.clean_keys_prefixed_with('[cenit]')
  end

  def scope_current_account
    Account.current = nil
    clean_thread_cache
    if current_user && current_user.account.nil?
      current_user.account = current_user.accounts.first || Account.new_for_create(owner: current_user)
      current_user.save(validate: false)
    end
    Account.current = current_user.account if signed_in?
    yield
  ensure
    optimize
    if (account = Account.current) && account.changed?
      account.save(discard_events: true)
    end
    clean_thread_cache
  end

  def after_sign_in_path_for(resource_or_scope)
    if params[:return_to]
      store_location_for(resource_or_scope, params[:return_to])
    else
      stored_location_for(resource_or_scope) || signed_in_root_path(resource_or_scope)
    end
  end

  def after_sign_out_path_for(resource_or_scope)
    params[:return_to] || ENV['SING_OUT_URL'] || root_path
  end
end

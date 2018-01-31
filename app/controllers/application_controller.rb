class ApplicationController < ActionController::Base
  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.

  protect_from_forgery with: :null_session,
    if: Proc.new { |c| c.request.format =~ %r{application/json} }

  rescue_from CanCan::AccessDenied, RailsAdmin::ActionNotAllowed do |exception|
    if _current_user
      redirect_to main_app.root_path, :alert => exception.message
    else
      redirect_to new_session_path(User)
    end
  end

  def doorkeeper_oauth_client
    @client ||= OAuth2::Client.new(DOORKEEPER_APP_ID, DOORKEEPER_APP_SECRET, :site => DOORKEEPER_APP_URL)
  end

  # expired?
  # refresh!
  def doorkeeper_access_token
    opts = {}
    if current_user
      opts[:refresh_token] = current_user.doorkeeper_refresh_token
      opts[:expires_at] = current_user.doorkeeper_expires_at
    end
    @token ||= OAuth2::AccessToken.new(doorkeeper_oauth_client, current_user.doorkeeper_access_token, opts) if current_user
  end

  around_filter :scope_current_account

  protected

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
      current_user.add_role(:admin) unless current_user.has_role?(:admin)
      current_user.account = Account.create_with_owner(owner: current_user)
      current_user.save(validate: false)
    end
    Account.current = current_user.account.target if signed_in?
    yield
  ensure
    optimize
    if (account = Account.current)
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

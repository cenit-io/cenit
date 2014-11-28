class ApplicationController < ActionController::Base
  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  
  protect_from_forgery with: :null_session,
    if: Proc.new { |c| c.request.format =~ %r{application/json} }
  
  #protect_from_forgery with: :exception
  
  around_filter :scope_current_account

  private
  
    def scope_current_account
      Account.current = current_user.account if signed_in?
      yield
    ensure
      Account.current = nil
    end
  
end
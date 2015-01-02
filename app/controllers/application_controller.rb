class ApplicationController < ActionController::Base
  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  
  protect_from_forgery with: :null_session,
    if: Proc.new { |c| c.request.format =~ %r{application/json} }
  
  #protect_from_forgery with: :exception
  
  rescue_from CanCan::AccessDenied do |exception|
    puts "^^^^^^^^^^^^^^ entro en can can "
     redirect_to 'http://localhost:3001', :alert => exception.message
  end
  
  around_filter :scope_current_account

  private
  
    def scope_current_account
      if current_user && current_user.account.nil?
         current_user.add_role(:admin) unless current_user.has_role?(:admin)
         current_user.account = Account.create_with_owner(owner: current_user)
         current_user.save(validate: false)
       end 
      Account.current = current_user.account if signed_in?
      yield
    ensure
      Account.current = nil
    end
  
end
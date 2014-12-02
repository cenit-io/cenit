module Setup
  class BaseController < ApplicationController
    respond_to :json
    before_action :authorize
    
    protected
    
    def authorize
      # we are using token authentication via header.
      key = request.headers['X-User-Key']
      token = request.headers['X-User-Access-Token']
      user = User.find_by(key: key) if key && token
      
      if user && Devise.secure_compare(user.authentication_token, token) && user.has_role?(:admin)
        #TODO: Check if 'X-Hub-Timestamp' belong to a small time window around Time.now
        Account.current = user.account
        return true
      end

      render json: 'Unauthorized!', status: :unprocessable_entity 
      return false
    end
    
  end
end

module Setup
  class BaseController < ApplicationController
    respond_to :json
    before_filter :authorize
    
    protected
    def authorize
      # we are using token authentication via header.
      key = request.headers['X-Hub-Store']
      token = request.headers['X-Hub-Access-Token']
      connection = Setup::Connection.unscoped.find_by(key: key) if key && token
      
      if connection && Devise.secure_compare(connection.authentication_token, token)
        #TODO: Check if 'X-Hub-Timestamp' belong to a small time window around Time.now
        Account.current = connection.account
        return true
      else
        render json: 'Unauthorized!', status: :unprocessable_entity 
        return false
      end
    end
  end
end

module Cenit
  class ApiController < ApplicationController
    before_filter :save_request_data, :authorize
    rescue_from Exception, :with => :exception_handler

    def consume
      response = {}
      @objects.each do |obj|
        handler = Handler.new(@message, obj)
        response.merge(handler.process)
      end
      response_handler = Handler.new(@message)
      responder = response_handler.response(response, 202)
      render json: responder, root: false, status: responder.code
    end

    protected
    def authorize
      # we are using token authentication via header.
      key = request.headers['X-Hub-Store']
      token = request.headers['X-Hub-Access-Token']
      connection = Setup::Connection.unscoped.find_by(key: key)

      if connection && Devise.secure_compare(connection.authentication_token, token)
        #TODO: Check if 'X-Hub-Timestamp' belong to a small time window around Time.now
        Account.current = connection.account
        return true
      else
        response_handler = Handler.new(@message)
        responder = response_handler.response('Unauthorized!', 401)
        render json: responder, root: false, status: responder.code
        return false
      end
    end

    def exception_handler(exception)
      exception_handler = Handler.new(@message)
      responder = exception_handler.response(exception.message, 500)
      responder.backtrace = exception.backtrace.to_s
      render json: responder, root: false, status: responder.code
      return false
    end

    def save_request_data
      @objects = params[:api].keys.map(&:singularize)
      @message = params[:api].to_json
    end

  end
end

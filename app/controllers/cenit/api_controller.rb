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
    rescue Exception => e
      puts "ERROR: #{e.inspect}"
    end

    protected
    def authorize
      key = request.headers['X-Hub-Store']
      token = request.headers['X-Hub-Access-Token']

      unless Account.set_current_with_connection(key, token) 
        response_handler = Handler.new(@message)
        responder = response_handler.response('Unauthorized!', 401)
        render json: responder, root: false, status: responder.code
        return false
      end
      true
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

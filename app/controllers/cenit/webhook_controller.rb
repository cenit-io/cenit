  module Cenit
    class WebhookController < ActionController::Base
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
        
        key = request.headers['X-Hub-Store']
        token = request.headers['X-Hub-Access-Token']
        @endpoint = Setup::Connection.unscoped.find_by(key: key, token: token)
        unless @endpoint
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
        @objects = params[:webhook].keys.map {|k| k.singularize}
        @message = params[:webhook].to_json
      end

    end
  end

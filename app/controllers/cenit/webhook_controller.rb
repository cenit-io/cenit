  module Cenit
    class WebhookController < ActionController::Base
      before_filter :save_request_data, :authorize
      rescue_from Exception, :with => :exception_handler

      def consume
        @objects.each do |obj|
          handler = Handler::Base.build_handler(obj, @message, @endpoint)
          responder = handler.process
          render json: responder, root: false, status: responder.code
        end
      end

      protected
      def authorize
        store = request.headers['X-Hub-Store']
        token = request.headers['X-Hub-Access-Token']
        @endpoint = Setup::Connection.where(store: store, token: token).first
        unless @endpoint
          base_handler = Handler::Base.new(@message)
          responder = base_handler.response('Unauthorized!', 401)
          render json: responder, root: false, status: responder.code
          return false
        end
      end

      def exception_handler(exception)
        base_handler = Handler::Base.new(@message)
        responder = base_handler.response(exception.message, 500)
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

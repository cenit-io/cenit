  module Cenit
    class WebhookController < ActionController::Base
      before_filter :save_request_data   #, :authorize
      rescue_from Exception, :with => :exception_handler

      # TODO: consider attribute objects
      def consume
        handler = Handler::Base.build_handler(@object, @message, @endpoint)
        responder = handler.process
        render json: responder, root: false, status: responder.code
      end

      protected
      def authorize
        store = request.headers['HTTP_X_HUB_STORE']
        token = request.headers['HTTP_X_HUB_TOKEN']
        @endpoint = Setup::Connection.where(store: store, token: token).first
        unless @endpoint
          base_handler = Handler::Base.new(@message)
          responder = base_handler.response('Unauthorized!', 401)
          render json: responder, root: false, status: responder.code
          return false
        end
      end

      def exception_handler(exception)
        base_handler = Handler::Base.new(@webhook_body)
        responder = base_handler.response(exception.message, 500)
        responder.backtrace = exception.backtrace.to_s
        render json: responder, root: false, status: responder.code
        return false
      end

      # TODO: change object to called_objects
      def save_request_data
        @object = params[:webhook].keys.first.singularize
        @message = params[:webhook].to_json
      end

    end
  end

  module Cenit
    class WebhookController < ActionController::Base
      before_filter :save_request_data   #, :authorize
      rescue_from Exception, :with => :exception_handler

      # TODO: consider attribute called_objects
      def consume
        handler = Handler::Base.build_handler(@called_object, @webhook_body)
        responder = handler.process
        render json: responder, root: false, status: responder.code
      end

      protected
      def authorize
        unless request.headers['HTTP_X_HUB_STORE'] == Hub::Config[:hub_store_id] && request.headers['HTTP_X_HUB_TOKEN'] == Hub::Config[:hub_token]
          base_handler = Handler::Base.new(@webhook_body)
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

      # TODO: change called_object to called_objects
      def save_request_data
        @called_object = params[:webhook].keys.first.singularize
        @webhook_body = params[:webhook].to_json
      end

    end
  end

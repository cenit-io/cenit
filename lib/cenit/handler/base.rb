require 'json'

module Cenit
  module Handler
    class Base

      attr_accessor :payload, :parameters, :request_id

      def initialize(message, store)
        self.payload = ::JSON.parse(message).with_indifferent_access
        self.request_id = payload.delete(:request_id)
        if payload.key? :parameters
          if payload[:parameters].is_a? Hash
            self.parameters = payload.delete(:parameters).with_indifferent_access
          end
        end
        self.parameters ||= {}
      end

      def self.build_handler(object, message, store)
        klass = ("Cenit::Handler::" + object.capitalize + "Handler").constantize
        klass.new(message, store)
      end

      def response(message, code = 200)
        Cenit::Responder.new(@request_id, message, code)
      end

      def process
        raise "Please implement the process method in your handler"
      end

    end
  end
end

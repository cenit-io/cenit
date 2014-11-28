require 'json'

module Cenit
  class Handler

      attr_accessor :payload, :parameters, :request_id, :model

      String

      def initialize(message, model=nil)
        self.payload = ::JSON.parse(message).with_indifferent_access
        self.request_id = payload.delete(:request_id)
        if payload.key? :parameters
          if payload[:parameters].is_a? Hash
            self.parameters = payload.delete(:parameters).with_indifferent_access
          end
        end
        self.parameters ||= {}
        self.model = model
      end

      def response(message, code = 200)
        Cenit::Responder.new(@request_id, message, code)
      end

      def process
        return {} if self.model.nil?

        klass = self.model.camelize.constantize
        root = self.model.pluralize
        count = 0
        self.payload[root].each do |obj|

          next if obj[:id].empty? rescue obj[:id] = obj[:id].to_s

          @object = klass.where(id: obj[:id]).first
          if @object
            @object.update_attributes(obj)
          else
            @object = klass.new(obj)
          end
          count += 1 if @object.save
        end
        {root => count}
      end

  end
end

require 'json'

module Cenit
  class Handler
      attr_accessor :payload, :parameters, :request_id, :model

      def initialize(message, model = nil)
        self.payload = ::JSON.parse(message).with_indifferent_access
        self.request_id = payload.delete(:request_id)
        self.parameters = payload.delete(:parameters).with_indifferent_access || {} if payload[:parameters].is_a?(Hash)
        self.model = model
      end

      def response(message, code = 200)
        Cenit::Responder.new(@request_id, message, code)
      end

      def process
        return {} unless model
        return {} unless data_type = Setup::DataType.find_by(name: model.camelize)

        klass = data_type.model
        root = self.model.pluralize
        count = 0
        self.payload[root].each do |obj|
          next if obj[:id].blank?
          obj[:id] = obj[:id].to_s
          @object = klass.where(id: obj[:id]).first
          @object ? @object.update_attributes!(obj) : @object = klass.create!(obj)
          count += 1
        end
        {root => count}
      end

  end
end

require 'json'

module Cenit
  class Handler

      attr_accessor :payload, :parameters, :request_id, :model

      def initialize(message, model=nil)
        self.payload = ::JSON.parse(message).with_indifferent_access
        self.request_id = payload.delete(:request_id)
        self.parameters = payload.delete(:parameters).with_indifferent_access if payload.key?(:parameters) && payload[:parameters].is_a?( Hash)
        self.parameters ||= {}
        self.model = model
      end

      def response(message, code = 200)
        Cenit::Responder.new(@request_id, message, code)
      end

      def process
        return {} if self.model.nil?

        data_type = Setup::DataType.where(:name => self.model.camelize).first
        return {} unless data_type

        klass = data_type.model
        root = self.model.pluralize
        count = 0
        self.payload[root].each do |obj|
          next if obj[:id].empty? rescue obj[:id] = obj[:id].to_s
          @object = klass.where(id: obj[:id]).first
          @object ? @object.update_attributes(obj) : (@object = klass.new(obj))
          count += 1 if @object.save
        end
        {root => count}
      end

  end
end

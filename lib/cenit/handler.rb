require 'json'

module Cenit
  class Handler
    attr_accessor :payload, :parameters, :request_id

    def initialize(message)
      self.payload = ::JSON.parse(message).with_indifferent_access
      self.request_id = payload.delete(:request_id)
      self.parameters = payload.delete(:parameters).with_indifferent_access if payload[:parameters].is_a?(Hash)
      self.parameters ||= {}
    end

    def response(message, code = 200)
      Cenit::Responder.new(@request_id, message, code)
    end

    def process(model = nil)
      #TODO PUSH API
      return {} unless model
      return {} unless data_type = Setup::DataType.find_by(name: model.camelize)

      root = model.pluralize
      count = 0
      if self.payload[root].blank? == false and self.payload[root].is_a?(Array)
        self.payload[root].each do |obj|
          next if obj[:id].blank?
          model = data_type.new_from_json(obj.to_json)
          model.save()
          count += 1
        end
      else
        unless self.payload[root].blank? or self.payload[root][:id].blank?
          model = data_type.new_from_json(payload[root].to_json)
          model.save
          count += 1
        end
      end
      {root => count}
    end

  end
end

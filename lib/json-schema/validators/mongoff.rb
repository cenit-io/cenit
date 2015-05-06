require 'json-schema/attributes/mongoff_properties_attribute'
require 'json-schema/attributes/mongoff_required_attribute'
require 'json-schema/attributes/mongoff_type_attribute'

module JSON
  class Schema
    class Mongoff < JSON::Schema::Draft4
      def initialize
        super
        @attributes['properties'] = MongoffPropertiesAttribute
        @attributes['required'] = MongoffRequiredAttribute
        @attributes['type'] = MongoffTypeAttribute
        @names = ['mongoff']
      end

      JSON::Validator.register_validator(self.new)
    end
  end
end
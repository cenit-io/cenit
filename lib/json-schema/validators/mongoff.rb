require 'json-schema/attributes/mongoff_properties_attribute'
require 'json-schema/attributes/mongoff_required_attribute'
require 'json-schema/attributes/mongoff_type_attribute'
require 'json-schema/attributes/mongoff_ref_attribute'

module JSON
  class Schema
    class Mongoff < JSON::Schema::Draft4
      def initialize
        super
        @attributes['properties'] = JSON::Schema::MongoffPropertiesAttribute
        @attributes['required'] = JSON::Schema::MongoffRequiredAttribute
        @attributes['type'] = JSON::Schema::MongoffTypeAttribute
        @attributes['$ref'] = JSON::Schema::MongoffRefAttribute
        @names = ['mongoff']
      end

      JSON::Validator.register_validator(self.new)
    end
  end
end
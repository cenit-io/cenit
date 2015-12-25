require 'json-schema/attributes/mongoff_properties_attribute'
require 'json-schema/attributes/mongoff_required_attribute'
require 'json-schema/attributes/mongoff_type_attribute'
require 'json-schema/attributes/mongoff_ref_attribute'
require 'json-schema/attributes/formats/uint_format'

module JSON
  class Schema
    class Mongoff < JSON::Schema::Draft4
      def initialize
        super
        @attributes['properties'] = JSON::Schema::MongoffPropertiesAttribute
        @attributes['required'] = JSON::Schema::MongoffRequiredAttribute
        @attributes['type'] = JSON::Schema::MongoffTypeAttribute
        @attributes['$ref'] = JSON::Schema::MongoffRefAttribute

        @formats.merge!('uint32' => JSON::Schema::Uint32Format,
                        'uint64' => JSON::Schema::Uint64Format)

        @names = ['mongoff']
      end

      JSON::Validator.register_validator(self.new)
    end
  end
end
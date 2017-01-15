require 'json-schema/attributes/mongoff_properties_attribute'
require 'json-schema/attributes/mongoff_required_attribute'
require 'json-schema/attributes/mongoff_type_attribute'
require 'json-schema/attributes/mongoff_ref_attribute'
require 'json-schema/attributes/formats/uint_format'

module JSON

  class Validator

    class << self
      alias_method :json_schema_key_for, :schema_key_for

      def schema_key_for(uri)
        if uri.is_a?(Hash)
          uri
        else
          json_schema_key_for(uri)
        end
      end
    end

    def load_ref_schema(parent_schema, ref)
      ref = [ref] unless ref.is_a?(Array)
      ref.each do |r|
        schema_uri =
          if r.is_a?(String)
            absolutize_ref_uri(r, parent_schema.uri)
          else
            r
          end
        return true if self.class.schema_loaded?(schema_uri)

        schema = @options[:schema_reader].read(schema_uri)
        self.class.add_schema(schema)
        build_schemas(schema)
      end
    end
  end

  class Schema

    alias_method :json_schema_init, :initialize

    def initialize(schema, uri, parent_validator=nil)
      if uri.is_a?(Hash)
        uri.define_singleton_method(:fragment) { @_fragment }
        uri.define_singleton_method(:fragment=) { |f| @_fragment = f }
      end
      json_schema_init(schema, uri, parent_validator)
    end

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

      alias_method :json_schema_validator_validate, :validate

      def validate(current_schema, data, fragments, processor, options = {})
        if (processor_options = processor.instance_variable_get(:@options)) && (data_type = processor_options[:data_type])
          current_schema = JSON::Schema.new(data_type.merge_schema(current_schema.schema), current_schema.uri, current_schema.validator)
        end
        json_schema_validator_validate(current_schema, data, fragments, processor, options)
      end

      JSON::Validator.register_validator(self.new)
    end
  end
end
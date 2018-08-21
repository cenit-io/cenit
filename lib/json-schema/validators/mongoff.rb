require 'json-schema/attributes/mongoff_properties_attribute'
require 'json-schema/attributes/mongoff_required_attribute'
require 'json-schema/attributes/mongoff_type_attribute'
require 'json-schema/attributes/mongoff_ref_attribute'
require 'json-schema/attributes/formats/uint_format'
require 'json-schema/schema/reader'

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
      build = true
      ref = [ref] unless ref.is_a?(Array)
      ref.each do |r|
        schema_uri = schema = @options[:schema_reader].absolute_ref_uri(r, parent_schema.uri)
        if schema.is_a?(Hash)
          schema_uri = Addressable::URI.parse(schema.delete('id')) || absolutize_ref_uri(r, parent_schema.uri)
        else
          schema = nil
        end
        next if self.class.schema_loaded?(schema_uri)
        if schema
          schema = JSON::Schema.new(JSON::Validator.parse(schema.to_json), schema_uri)
        else
          schema = @options[:schema_reader].read(schema_uri)
        end
        self.class.add_schema(schema)
        build &&= build_schemas(schema)
      end
      build
    end
  end

  class Schema

    alias_method :json_schema_init, :initialize

    def initialize(schema, uri, parent_validator = nil)
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

    class Reader
      def absolute_ref_uri(ref, parent_uri)
        JSON::Validator.absolutize_ref_uri(ref, parent_uri)
      end
    end
  end
end
require 'json-schema'

module Cenit

  class JSONSchemaValidator < JSON::Validator

    def initialize(schema_data, data, opts={})
      super
    end

    class << self
      def validate(schema, data, opts={})
        begin
          validator = new(schema, data, opts)
          validator.validate
          return true
        rescue JSON::Schema::ValidationError, JSON::Schema::SchemaError
          return false
        end
      end

      def validate!(schema, data, opts={})
        validator = new(schema, data, opts)
        validator.validate
        return true
      end

      def fully_validate(schema, data, opts={})
        opts[:record_errors] = true
        validator = new(schema, data, opts)
        validator.validate
      end
    end

    def load_ref_schema(parent_schema, ref)
      if ref =~ /\A([A-Z]|[a-z])+(_|([0-9]|[A-Z]|[a-z])+)*(.([A-Z]|[a-z])+(_|([0-9]|[A-Z]|[a-z])+)*)*\Z/ && (ref == ref.camelize || ref == ref.camelize.underscore)
        JSON::Validator.add_schema(JSON::Schema.new({'type' => 'string'}, URI.parse(ref)))
      else
        super
      end
    end
  end
end
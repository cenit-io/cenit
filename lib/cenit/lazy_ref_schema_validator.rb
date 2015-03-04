module Cenit

  class LazyRefSchemaValidator < JSON::Schema::Validator
    def initialize
      super
      extend_schema_definition(JSON::Validator.default_validator.uri.to_s)
      @attributes["$ref"] = LazyRefAttribute
      @uri = JSON::Validator.default_validator.uri
    end
  end

  class LazyRefAttribute < JSON::Schema::RefAttribute
    # def self.validate(current_schema, data, fragments, processor, validator, options = {})
    #   begin
    #     super
    #   rescue Exception => ex
    #    raise ex unless (lazy_ref = current_schema.schema['$ref']) &&
    #         lazy_ref =~ /\A([A-Z]|[a-z])+(_|([0-9]|[A-Z]|[a-z])+)*(.([A-Z]|[a-z])+(_|([0-9]|[A-Z]|[a-z])+)*)*\Z/ &&
    #         (lazy_ref == lazy_ref.camelize || lazy_ref == lazy_ref.camelize.underscore)
    #
    #   end
    # end

    def self.get_referenced_uri_and_schema(s, current_schema, validator)
      begin
        super
      rescue Exception => ex
        raise ex unless (lazy_ref = s['$ref']) &&
            lazy_ref =~ /\A([A-Z]|[a-z])+(_|([0-9]|[A-Z]|[a-z])+)*(.([A-Z]|[a-z])+(_|([0-9]|[A-Z]|[a-z])+)*)*\Z/ &&
            (lazy_ref == lazy_ref.camelize || lazy_ref == lazy_ref.camelize.underscore)
        uri = URI.parse(lazy_ref)
        unless schema = JSON::Validator.schemas[uri.to_s]
          json_schema = case lazy_ref
                        when 'Date'
                          {'type' => 'string', 'format' => 'date'}
                        when 'DateTime'
                          {'type' => 'string', 'format' => 'date-time'}
                        when 'Time'
                          {'type' => 'string', 'format' => 'time'}
                        else
                          {'type' => 'string'}
                        end
          JSON::Validator.add_schema(schema = JSON::Schema.new(json_schema, uri))
        end
        [uri, schema]
      end
    end
  end
end
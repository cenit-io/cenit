require 'json-schema/attribute'
require 'json-schema/errors/schema_error'

module JSON
  class Schema
    class MongoffRefAttribute < Attribute

      class << self
        def validate(current_schema, data, fragments, processor, validator, options = {})
          for_each_referenced_uri_and_schema(current_schema.schema, current_schema, validator) do |uri, schema|
            if schema
              schema.validate(data, fragments, processor, options)
            elsif uri
              message = "The referenced schema '#{uri.to_s}' cannot be found"
              validation_error(processor, message, fragments, current_schema, self, options[:record_errors])
            else
              message = "The property '#{build_fragment(fragments)}' was not a valid schema"
              validation_error(processor, message, fragments, current_schema, self, options[:record_errors])
            end
          end
        end

        def for_each_referenced_uri_and_schema(s, current_schema, validator, &block)
          refs = s['$ref']
          refs = [refs] unless refs.is_a?(Array)
          refs.each do |ref|
            uri, schema = nil, nil

            temp_uri = Addressable::URI.parse(ref)
            if temp_uri.relative?
              temp_uri = current_schema.uri.clone
              # Check for absolute path
              path = ref.split('#')[0]
              if path.nil? || path == ''
                temp_uri.path = current_schema.uri.path
              elsif path[0, 1] == '/'
                temp_uri.path = Pathname.new(path).cleanpath.to_s
              else
                temp_uri = current_schema.uri.join(path)
              end
              temp_uri.fragment = ref.split('#')[1]
            end
            temp_uri.fragment = '' if temp_uri.fragment.nil?

            # Grab the parent schema from the schema list
            schema_key = temp_uri.to_s.split('#')[0] + '#'

            ref_schema = JSON::Validator.schema_for_uri(schema_key)

            if ref_schema
              # Perform fragment resolution to retrieve the appropriate level for the schema
              target_schema = ref_schema.schema
              fragments = temp_uri.fragment.split('/')
              fragment_path = ''
              fragments.each do |fragment|
                if fragment && fragment != ''
                  fragment = Addressable::URI.unescape(fragment.gsub('~0', '~').gsub('~1', '/'))
                  if target_schema.is_a?(Array)
                    target_schema = target_schema[fragment.to_i]
                  else
                    target_schema = target_schema[fragment]
                  end
                  fragment_path = fragment_path + "/#{fragment}"
                  if target_schema.nil?
                    raise SchemaError.new("The fragment '#{fragment_path}' does not exist on schema #{ref_schema.uri.to_s}")
                  end
                end
              end

              # We have the schema finally, build it and validate!
              uri = temp_uri
              schema = JSON::Schema.new(target_schema, temp_uri, validator)
            end

            block.call(uri, schema)
          end
        end
      end
    end
  end
end

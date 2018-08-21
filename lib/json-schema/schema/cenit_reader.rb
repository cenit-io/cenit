module JSON
  class Schema
    class CenitReader

      attr_reader :schema_finder

      def initialize(schema_finder)
        @schema_finder = schema_finder
      end

      def read(ref)
        #TODO Do it better than this (only for application start up)
        if ref.is_a?(Hash)
          uri = ref
        else
          uri = ref.scheme == 'file' ? ref.to_s.split('/').last : ref.to_s
          uri = uri.chop if uri.end_with?('#')
        end
        if (schema = schema_finder.find_ref_schema(uri))
          schema = schema.to_json unless schema.is_a?(String)
          JSON::Schema.new(JSON::Validator.parse(schema), ref)
        else
          raise Exception.new("Unresolved schema reference #{ref}")
        end
      end

      def absolute_ref_uri(ref, parent_uri)
        if (schema = schema_finder.find_ref_schema(ref))
          if schema.is_a?(Hash)
            schema
          else
            JSON.parse(schema)
          end
        else
          raise Exception.new("Unresolved schema reference #{ref}")
        end
      end
    end
  end
end

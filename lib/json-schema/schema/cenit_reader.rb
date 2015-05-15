module JSON
  class Schema
    class CenitReader

      attr_reader :data_type

      def initialize(data_type)
        @data_type = data_type
      end

      def read(ref)
        #TODO Do it better than this (only for application start up)
        uri = ref.scheme == 'file' ? ref.to_s.split('/').last : ref.to_s
        if schema = data_type.find_ref_schema(uri)
          JSON::Schema.new(JSON::Validator.parse(schema.to_json), ref)
        else
          raise Exception.new("Unresolved schema reference #{ref}")
        end
      end
    end
  end
end

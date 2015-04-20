module JSON
  class Schema
    class CenitReader

      attr_reader :data_type

      def initialize(data_type)
        @data_type = data_type
      end

      def read(ref)
        if schema = data_type.find_ref_schema(ref.to_s)
          JSON::Schema.new(JSON::Validator.parse(schema.to_json), ref)
        else
          raise Exception.new("Unresolved schema reference #{ref}")
        end
      end
    end
  end
end

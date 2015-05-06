module JSON
  class Schema
    class MongoffTypeAttribute < JSON::Schema::TypeV4Attribute
      class << self
        def validate(current_schema, data, fragments, processor, validator, options = {})
          union = true
          types = current_schema.schema['type']

          return if types == 'string' &&
            %w(date date-time time).include?(format = current_schema.schema['format']) &&
            data.is_a?(format.gsub('-', '_').camelize.constantize)

          if !types.is_a?(Array)
            types = [types]
            union = false
          end

          return if types.any? { |type| data_valid_for_type?(data, type) }

          types = types.map { |type| type.is_a?(String) ? type : '(schema)' }.join(', ')
          message = format(
            "The property '%s' of type %s did not match %s: %s",
            build_fragment(fragments),
            data.class,
            union ? 'one or more of the following types' : 'the following type',
            types
          )

          validation_error(processor, message, fragments, current_schema, self, options[:record_errors])
        end
      end
    end
  end
end
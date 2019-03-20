module JSON
  class Schema
    class MongoffTypeAttribute < JSON::Schema::TypeV4Attribute

      DATE_FORMATS = %w(date date-time time)
      DATE_CLASSES = DATE_FORMATS.collect { |format| format.gsub('-', '_').camelize.constantize }

      class << self
        def validate(current_schema, data, fragments, processor, validator, options = {})
          union = true
          types = current_schema.schema['type']

          return if types == 'string' &&
                    DATE_FORMATS.include?(format = current_schema.schema['format']) &&
                    DATE_CLASSES.any? { |klass| data.is_a?(klass) }

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
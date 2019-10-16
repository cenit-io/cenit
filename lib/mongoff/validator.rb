module Mongoff
  module Validator
    extend self

    # Any Type
    ANY_TYPE_KEYWORDS = %w(type enum const)
    # Numeric
    NUMERIC_KEYWORDS = %w(multipleOf maximum exclusiveMaximum minimum exclusiveMinimum)
    # String
    STRING_KEYWORDS = %w(maxLength minLength pattern)
    # Array
    ARRAY_KEYWORDS = %w(items additionalItems maxItems minItems uniqueItems contains)
    # Object
    OBJECT_KEYWORDS = %w(maxProperties minProperties required properties patternProperties additionalProperties dependencies propertyNames)
    # Conditional
    CONDITIONAL_KEYWORDS = %w(if then else)
    # Logic
    LOGIC_KEYWORDS = %w(allOf anyOf oneOf not)
    # Format
    FORMAT_KEYWORDS = %w(format)
    # String-Encoding Non-JSON Data
    ENCODING_KEYWORDS = %w(contentEncoding contentMediaType)
    # Default Annotation
    DEFAULT_KEYWORD = 'default'
    # Annotations
    ANNOTATION_KEYWORDS = %w(title description readOnly writeOnly examples) + [DEFAULT_KEYWORD]

    # Instance Validation Keywords
    INSTANCE_VALIDATION_KEYWORDS =
      ANY_TYPE_KEYWORDS +
        NUMERIC_KEYWORDS +
        STRING_KEYWORDS +
        ARRAY_KEYWORDS +
        OBJECT_KEYWORDS +
        LOGIC_KEYWORDS +
        FORMAT_KEYWORDS +
        [DEFAULT_KEYWORD]

    def soft_validates(instance, options = {})
      validate_instance(instance, options)
    rescue Exception => ex
      _handle_error(instance, ex)
    ensure
      _check_soft_errors(instance)
    end

    def _check_soft_errors(instance)
      if instance&.instance_variable_defined?(:@__soft_errors) &&
         (soft_errors = instance.remove_instance_variable(:@__soft_errors)) &&
         instance.errors.blank?
        soft_errors.each do |property, msg|
          instance.errors.add(:base, "property #{property} #{msg}")
        end
      end
    end

    def validate_instance(instance, *args)
      options =
        if args.last.is_a?(Hash)
          args.pop
        else
          {}
        end
      schema = args[0] || instance.orm_model.schema
      data_type = args[1] || instance.orm_model.data_type
      state = {}
      validation_keys = INSTANCE_VALIDATION_KEYWORDS.select { |key| schema.key?(key) }
      prefixes = %w(check)
      if options[:check_schema]
        prefixes.unshift('check_schema')
      end
      validation_keys.each do |key|
        prefixes.each do |prefix|
          key_method_name = "#{prefix}_#{key}".to_sym
          key_method =
            begin
              method(key_method_name)
            rescue
              nil
            end
          if key_method
            args = [schema[key], instance]
            args << state if key_method.arity > 2
            args << data_type if key_method.arity > 3
            args << options if key_method.arity > 4
            key_method.call(*args)
          end
        end
      end
    ensure
      _check_soft_errors(instance)
    end

    def validate(schema)
      schema.each do |key, key_value|
        key_method = "check_schema_#{key}".to_sym
        if respond_to(key_method)
          send(key_method, key_value)
        end
      end
    end

    TYPE_MAP = {
      null: NilClass,
      boolean: Boolean,
      number: Numeric,
      string: Object,
      integer: Integer,
      object: Hash,
      array: Array,
      record: Mongoff::Record,
      record_array: Mongoff::RecordArray
    }

    def check_schema_type(type)
      raise "Invalid schema type #{type}" unless type.nil? || TYPE_MAP.key?(type.to_s.to_sym)
    end

    # Validation Keywords for Any Instance Type

    def check_type(type, instance, _, _, options)
      return if instance.nil? && options[:skip_nulls]
      type =
        if (instance.is_a?(Mongoff::Record) || instance.is_a?(Mongoff::RecordArray)) && instance.orm_model.modelable?
          if type == 'object'
            :record
          else
            :record_array
          end
        else
          type && type.to_sym
        end
      if type
        raise "of type #{instance.class} is not an instance for type #{type}" unless instance.is_a?(TYPE_MAP[type])
      else
        raise "of type #{instance.class} is not a valid JSON type" unless Cenit::Utility.json_object?(instance)
      end
    end

    def check_schema_enum(enum)
      raise "Invalid schema enum of type #{enum.class}, array is expected" unless enum.is_a?(Array)
    end

    def check_enum(enum, instance)
      raise "is not included in the enumeration" unless enum.include?(instance)
    end

    def check_const(const, instance)
      raise "is not the const value #{const}" unless const == instance
    end

    # Validation Keywords for Numeric Instances (number and integer)

    def check_schema_multipleOf(value)
      _check_type(:multipleOf, value, Numeric)
      raise "Invalid value for multipleOf, strictly greater than zero is expected" unless value.positive?
    end

    def check_multipleOf(value, instance)
      raise "is not multiple of #{value}" if instance.is_a?(Numeric) && instance % value != 0
    end

    def check_schema_maximum(value)
      _check_type(:maximum, value, Numeric)
    end

    def check_maximum(value, instance, state)
      raise "maximum is #{value}" if instance.is_a?(Numeric) && instance > value
      state[:maximum] = value
    end

    def check_schema_exclusiveMaximum(value)
      _check_type(:exclusiveMaximum, value, Boolean)
    end

    def check_exclusiveMaximum(value, instance, state)
      raise "must be strictly less than #{value}" if value && (maximum = state[:maximum]) && instance.is_a?(Numeric) && instance >= maximum
    end

    def check_schema_minimum(value)
      _check_type(:minimum, value, Numeric)
    end

    def check_minimum(value, instance, state)
      raise "minimum is #{value}" if instance.is_a?(Numeric) && instance < value
      state[:minimum] = value
    end

    def check_schema_exclusiveMinimum(value)
      _check_type(:exclusiveMinimum, value, Boolean)
    end

    def check_exclusiveMinimum(value, instance, state)
      raise "must be strictly greater than #{value}" if value && (minimum = state[:minimum]) && instance.is_a?(Numeric) && instance <= minimum
    end

    # Validation Keywords for Strings

    def check_schema_maxLength(value)
      _check_type(:maxLength, value, Integer)
      raise "Invalid value for maxLength, a non negative value is expected" if value.negative?
    end

    def check_maxLength(value, instance)
      raise "is too long (#{instance.length} of #{value} max)" if instance.is_a?(String) && instance.length > value
    end

    def check_schema_minLength(value)
      _check_type(:maxLength, value, Integer)
      raise "Invalid value for minLength, a non negative value is expected" if value.negative?
    end

    def check_minLength(value, instance)
      raise "is too short (#{instance.length} for #{value} min)" if instance.is_a?(String) && instance.length < value
    end

    def check_schema_pattern(value)
      _check_type(:pattern, value, String)
    end

    def check_pattern(value, instance)
      raise "does not match the pattern #{value}" if instance.is_a?(String) && !Regexp.new(value).match(instance)
    end

    # Validation Keywords for Arrays

    def check_schema_items(items_schema)
      _check_type(:items, items_schema, Hash, Array)
      if items_schema.is_a?(Hash)
        validate(items_schema)
      else # Is an array
        raise "array of schemas for items is not yet supported" # TODO Support array of schemas for items and additionalItems validation keyword
      end
    end

    def check_items(items_schema, items, _, data_type, options)
      if items.is_a?(Mongoff::RecordArray)
        items_schema = items.orm_model.schema
        data_type = items.orm_model.data_type
        has_errors = false
        items.each do |item|
          item.errors.clear
          begin
            validate_instance(item, items_schema, data_type, options)
          rescue RuntimeError => ex
            _handle_error(item, ex)
          end
          has_errors ||= item.errors.present?
        end
        raise SoftError, 'has errors' if has_errors
      elsif items.is_a?(Array)
        items_schema = data_type.merge_schema(items_schema)
        items.each_with_index do |item, index|
          begin
            validate_instance(item, items_schema, data_type, options)
          rescue RuntimeError => ex
            raise "on item #{index}, #{ex.message}"
          end
        end
      end
    end

    def check_schema_maxItems(max)
      _check_type(:maxItems, max, Integer)
      raise "Invalid value for maxItems, a non negative value is expected" if max.negative?
    end

    def check_maxItems(max, items)
      if items.is_a?(Mongoff::RecordArray) || items.is_a?(Array)
        raise "has too many items (#{instance.count} of #{max} max)" if items.count > max
      end
    end

    def check_schema_minItems(min)
      _check_type(:minItems, min, Integer)
      raise "Invalid value for minItems, a non negative value is expected" if min.negative?
    end

    def check_minItems(min, items)
      if items.is_a?(Mongoff::RecordArray) || items.is_a?(Array)
        raise "has too few items (#{instance.count} for #{min} min)" if items.count < min
      end
    end

    def check_schema_uniqueItems(unique)
      _check_type(:uniqueItems, unique, Boolean)
    end

    def check_uniqueItems(min, items)
      if items.is_a?(Mongoff::RecordArray) || items.is_a?(Array)
        set = Set.new(items)
        raise "items are not unique" if set.count < items.count
      end
    end

    def check_schema_contains(schema)
      validate(schema)
    end

    def check_contains(schema, items, _, data_type, options)
      schema = data_type.merge_schema(schema)
      if items.is_a?(Mongoff::RecordArray) || items.is_a?(Array)
        data_type = items.orm_model.data_type if items.is_a?(Mongoff::RecordArray)
        items.each do |item|
          begin
            validate_instance(item, schema, data_type, options)
            return
          rescue
            next
          end
        end
        raise 'no item match against the contains schema'
      end
    end

    # Validation Keywords for Objects

    def check_schema_required(value)
      _check_type(:properties, value, Array)
      value.each do |property_name|
        _check_type('property name', property_name, String)
      end
    end

    def check_required(properties, instance)
      return unless instance
      has_errors = false
      if instance.is_a?(Mongoff::Record)
        stored_properties = instance.orm_model.stored_properties_on(instance)
        properties.each do |property|
          unless stored_properties.include?(property)
            has_errors = true
            instance.errors.add(property, "is required")
          end
        end
      elsif instance.is_a?(Hash)
        properties.each do |property|
          unless instance.key?(property)
            has_errors = true
            instance.errors.add(property, "is required")
          end
        end
      end
      raise SoftError, 'has errors' if has_errors
    end

    def check_schema_properties(value)
      _check_type(:properties, value, Hash)
      value.each do |property, schema|
        begin
          validate(schema)
        rescue RuntimeError => ex
          raise "Property #{property} schema is not valid: #{ex.message}"
        end
      end
    end

    def check_properties(properties, instance, state, data_type, options)
      unless (checked_properties = state[:checked_properties])
        checked_properties = state[:checked_properties] = Set.new
      end
      if instance.is_a?(Mongoff::Record)
        unless state[:instance_clear]
          instance.errors.clear
          state[:instance_clear]
        end
        report_error = false
        if instance.changed?
          model = instance.orm_model
          model.stored_properties_on(instance).each do |property|
            next unless properties.key?(property)
            checked_properties << property
            begin
              property_data_type =
                if (property_model = model.property_model(property))
                  property_model.data_type
                else
                  data_type
                end
              validate_instance(instance[property], model.property_schema(property), property_data_type, options)
            rescue RuntimeError => ex
              _handle_error(instance, ex, property)
              report_error = true
            end
          end
        end
        raise SoftError, 'has errors' if report_error
      elsif instance.is_a?(Hash)
        instance.each do |property, value|
          next unless properties.key?(property)
          checked_properties << property
          validate_instance(value, data_type.merge_schema(properties[property]), data_type, options)
        end
      end
    end

    def check_schema_maxProperties(max)
      _check_type(:maxProperties, max, Integer)
      raise "Invalid value for maxProperties, a non negative value is expected" if max.negative?
    end

    def check_maxProperties(max, instance)
      if instance.is_a?(Mongoff::Record) || instance.is_a?(Hash)
        instance = instance.orm_model.stored_properties_on(instance) if instance.is_a?(Mongoff::Record)
        raise "has too many properties (#{instance.size} of #{max} max)" if instance.size > max
      end
    end

    def check_schema_minProperties(min)
      _check_type(:minProperties, min, Integer)
      raise "Invalid value for minProperties, a non negative value is expected" if min.negative?
    end

    def check_minProperties(min, instance)
      if instance.is_a?(Mongoff::Record) || instance.is_a?(Hash)
        instance = instance.orm_model.stored_properties_on(instance) if instance.is_a?(Mongoff::Record)
        raise "has too few properties (#{instance.size} for #{min} min)" if instance.size < min
      end
    end

    def check_schema_patternProperties(value)
      _check_type(:properties, value, Hash)
      value.each do |pattern, schema|
        begin
          raise "Property pattern #{pattern} is not regex compatible" unless pattern.is_a?(String)
          validate(schema)
        rescue RuntimeError => ex
          raise "Property pattern #{pattern} schema is not valid: #{ex.message}"
        end
      end
    end

    def check_patternProperties(patterns, instance, state, data_type, options)
      unless (checked_properties = state[:checked_properties])
        checked_properties = state[:checked_properties] = Set.new
      end
      patterns = patterns.collect { |pattern, schema| [Regex.new(pattern), schema] }.to_h
      merged_schemas = {}
      if instance.is_a?(Mongoff::Record)
        unless state[:instance_clear]
          instance.errors.clear
          state[:instance_clear]
        end
        report_error = false
        if instance.changed?
          model = instance.orm_model
          model.stored_properties_on(instance).each do |property|
            pattern = patterns.keys.detect { |regex| regex.match(property) }
            next unless pattern
            checked_properties << property
            begin
              property_data_type =
                if (property_model = model.property_model(property))
                  property_model.data_type
                else
                  data_type
                end
              unless (schema = merged_schemas[property])
                schema = merged_schemas[property] = property_data_type.merge_schema(patterns[pattern])
              end
              validate_instance(instance[property], schema, property_data_type, options)
            rescue RuntimeError => ex
              report_error = true
              _handle_error(instance, ex, property) do |msg|
                "#{msg} (against additional property pattern #{pattern})"
              end
            end
          end
        end
        raise SoftError, 'has errors' if report_error
      elsif instance.is_a?(Hash)
        instance.each do |property, value|
          pattern = patterns.keys.detect { |regex| regex.match(property) }
          next unless pattern
          checked_properties << property
          unless (schema = merged_schemas[property])
            schema = merged_schemas[property] = data_type.merge_schema(patterns[pattern])
          end
          begin
            validate_instance(value, schema, data_type, options)
          rescue RuntimeError => ex
            _handle_error(instance, ex, property) do |msg|
              "#{msg} (against additional property pattern #{pattern})"
            end
          end
        end
      end
    end

    def check_schema_additionalProperties(schema)
      validate(schema)
    end

    def check_additionalProperties(schema, instance, state, data_type, options)
      unless (checked_properties = state[:checked_properties])
        checked_properties = state[:checked_properties] = Set.new
      end
      schema = data_type.merge_schema(schema)
      if instance.is_a?(Mongoff::Record)
        unless state[:instance_clear]
          instance.errors.clear
          state[:instance_clear]
        end
        report_error = false
        if instance.changed?
          model = instance.orm_model
          model.stored_properties_on(instance).each do |property|
            next if checked_properties.key?(property)
            begin
              property_data_type =
                if (property_model = model.property_model(property))
                  property_model.data_type
                else
                  data_type
                end
              validate_instance(instance[property], schema, property_data_type, options)
            rescue RuntimeError => ex
              report_error = true
              _handle_error(instance, ex, property) do |msg|
                "#{msg} (against additional properties schema)"
              end
            end
          end
        end
        raise SoftError, 'has errors' if report_error
      elsif instance.is_a?(Hash)
        instance.each do |property, value|
          next if checked_properties.key?(property)
          begin
            validate_instance(value, schema, data_type, options)
          rescue RuntimeError => ex
            raise "#{ex.message} (against additional properties schema)"
          end
        end
      end
    end

    def check_schema_propertyNames(schema)
      validate(schema)
    end

    def check_propertyNames(schema, instance, state, data_type, options)
      schema = data_type.merge_schema(schema)
      if instance.is_a?(Mongoff::Record)
        unless state[:instance_clear]
          instance.errors.clear
          state[:instance_clear]
        end
        report_error = false
        if instance.changed?
          model = instance.orm_model
          model.stored_properties_on(instance).each do |property|
            begin
              validate_instance(property, schema, data_type, options)
            rescue RuntimeError => ex
              report_error = true
              _handle_error(instance, ex, property) do |msg|
                "name does not match the property names schema (#{msg})"
              end
            end
          end
        end
        raise SoftError, 'has errors' if report_error
      elsif instance.is_a?(Hash)
        instance.keys.each do |property|
          begin
            validate_instance(property, schema, data_type, options)
          rescue RuntimeError => ex
            raise "property name #{property} does not match property manes schema (#{ex.message})"
          end
        end
      end
    end

    # Utilities

    def _check_type(key, value, *klasses)
      unless klasses.any? { |klass| value.is_a?(klass) }
        raise "Invalid value for #{key} of type #{value.class} (#{value}), #{klass.to_sentence(last_word_connector: 'or')} is expected"
      end
    end

    def _handle_error(instance, err, property = :base)
      return unless instance
      msg =
        if block_given?
          yield err.message
        else
          err.message
        end
      if err.is_a?(SoftError)
        if instance.errors.blank?
          unless (soft_errors = instance.instance_variable_get(:@__soft_errors))
            instance.instance_variable_set(:@__soft_errors, soft_errors = {}.with_indifferent_access)
          end
          soft_errors[property] = msg
        end
      else
        instance.errors.add(property, msg)
      end
    end

    class SoftError < RuntimeError

    end
  end
end
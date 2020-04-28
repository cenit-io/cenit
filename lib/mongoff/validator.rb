# This implementation try to follow the JSON Schema Validation specification described at
#
# https://json-schema.org/draft/2019-09/json-schema-core.html
#
# https://json-schema.org/draft/2019-09/json-schema-validation.html
#
#

require 'resolv'

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
    ARRAY_KEYWORDS = %w(items additionalItems maxItems minItems uniqueItems contains maxContains minContains)
    # Object
    OBJECT_KEYWORDS = %w(maxProperties minProperties required dependentRequired properties patternProperties additionalProperties propertyNames)
    # Conditional
    CONDITIONAL_KEYWORDS = %w(if then else dependentSchemas)
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
        [DEFAULT_KEYWORD] +
        CONDITIONAL_KEYWORDS

    def soft_validates(instance, options = {})
      validate_instance(instance, options)
    rescue Error => ex
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

    def validate_instance(instance, options = {})
      unless (visited = options[:visited])
        visited = options[:visited] = Set.new
      end
      unless (soft_checked = visited.include?(instance))
        visited << instance if (mongoff = instance.is_a?(Mongoff::Record))
        begin
          data_type = options[:data_type] || (mongoff_model = instance.orm_model).data_type
          unless (schema = options[:schema]).is_a?(FalseClass)
            schema ||= (mongoff_model || data_type).schema
          end
          return if schema.is_a?(TrueClass)
          raise_path_less_error 'is not allowed' if schema.is_a?(FalseClass)
          schema = data_type.merge_schema(schema)
          state = {}
          validation_keys = []
          props = items = false
          INSTANCE_VALIDATION_KEYWORDS.each do |key|
            next unless schema.key?(key)
            validation_keys << key
            if props
              if key == 'additionalProperties'
                props = false
              end
            elsif key == 'properties'
              props = true
            end
            if items
              if key == 'additionalItems'
                items = false
              end
            elsif key == 'items'
              items = true
            end
          end
          validation_keys << 'additionalProperties' if props
          validation_keys << 'additionalItems' if items
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
                args << schema if key_method.arity > 5
                key_method.call(*args)
              end
            end
          end
        ensure
          visited.delete(instance) if mongoff
        end
      end
    ensure
      _check_soft_errors(instance) unless soft_checked
    end

    def is_valid?(schema)
      begin
        validate(schema)
        true
      rescue
        false
      end
    end

    def validate(schema)
      return if schema.is_a?(TrueClass) || schema.is_a?(FalseClass)
      _check_type(:schema, schema, Hash)
      schema.each do |key, key_value|
        key_method = "check_schema_#{key}".to_sym
        if respond_to?(key_method)
          send(key_method, key_value)
        end
      end
    end

    TYPE_MAP = {
      null: NilClass,
      boolean: Boolean,
      number: Numeric,
      string: String,
      integer: Integer,
      object: Hash,
      array: Array
    }

    def check_schema_type(types)
      return if types.nil?
      types = [types] unless types.is_a?(Array)
      types = types.map(&:to_s).map(&:to_sym)
      raise_path_less_error "types are not unique" unless types.uniq.length === types.length
      types.each do |type|
        raise_path_less_error "type #{type} is invalid" unless TYPE_MAP.key?(type)
      end
    end

    # Default Behavior

    def check_schema_default(default)
      raise_path_less_error "Invalid default value of type #{default.class}, JSON value is expected" unless ::Cenit::Utility.json_object?(default)
    end

    def check_default(_default, _instance)
      # Nothing to do here
    end

    # Validation Keywords for Any Instance Type

    def check_type(types, instance, _, _, options, schema)
      return if instance.nil? && options[:skip_nulls]
      if types
        types = [types] unless types.is_a?(Array)
        types = types.map(&:to_s).map(&:to_sym)
        super_types = types.map do |type|
          case type
          when :object
            if instance.is_a?(Mongoff::Record) && instance.orm_model.modelable?
              Mongoff::Record
            elsif instance.is_a?(Setup::OrmModelAware)
              Setup::OrmModelAware
            else
              TYPE_MAP[type]
            end
          when :array
            if instance.is_a?(Mongoff::RecordArray) && instance.orm_model.modelable?
              Mongoff::RecordArray
            elsif instance.is_a?(Mongoid::Relations::Targets::Enumerable)
              Mongoid::Relations::Targets::Enumerable
            else
              TYPE_MAP[type]
            end
          when :string
            if !instance.is_a?(String) && schema.key?('format')
              Object
            else
              TYPE_MAP[type]
            end
          else
            TYPE_MAP[type]
          end
        end
        unless super_types.any? { |type| instance.is_a?(type) }
          msg =
            if super_types.length == 1
              "of type #{instance.class} is not an instance of type #{types[0]}"
            else
              "of type #{instance.class} is not an instance of any type #{types.to_sentence}"
            end
          raise_path_less_error msg
        end
      else
        raise_path_less_error "of type #{instance.class} is not a valid JSON type" unless Cenit::Utility.json_object?(instance)
      end
    end

    def check_schema_enum(enum)
      raise_path_less_error "Invalid enum schema of type #{enum.class}, array is expected" unless enum.is_a?(Array)
      raise_path_less_error "Empty enum array is not allowed" if enum.length === 0
      raise_path_less_error "Enum elements are not unique" unless enum.uniq.length == enum.length
    end

    def check_enum(enum, instance)
      raise_path_less_error "is not included in the enumeration" unless enum.include?(instance)
    end

    def check_schema_const(const)
      raise_path_less_error "Invalid const schema of type #{const.class}, JSON value is expected" unless ::Cenit::Utility.json_object?(const)
    end

    def check_const(const, instance)
      raise_path_less_error "is not the const value '#{const}'" unless const == instance
    end

    # Validation Keywords for Numeric Instances (number and integer)

    def check_schema_multipleOf(value)
      _check_type(:multipleOf, value, Numeric)
      raise_path_less_error "Invalid value for multipleOf, strictly greater than zero is expected" unless value.positive?
    end

    def check_multipleOf(value, instance)
      raise_path_less_error "is not multiple of #{value}" if instance.is_a?(Numeric) && (instance / value).modulo(1) != 0
    end

    def check_schema_maximum(value)
      _check_type(:maximum, value, Numeric)
    end

    def check_maximum(maximum, instance, _state, _data_type, _options, schema)
      if instance.is_a?(Numeric)
        if schema['exclusiveMaximum'].is_a?(TrueClass)
          raise_path_less_error "must be strictly less than #{maximum}" if instance >= maximum
        else
          raise_path_less_error "expected to be maximum #{maximum}" if instance > maximum
        end
      end
    end

    def check_schema_exclusiveMaximum(value)
      _check_type(:exclusiveMaximum, value, Numeric, Boolean)
    end

    def check_exclusiveMaximum(maximum, instance)
      if maximum.is_a?(Numeric) && instance.is_a?(Numeric) && instance >= maximum
        raise_path_less_error "must be strictly less than #{maximum}"
      end
    end

    def check_schema_minimum(value)
      _check_type(:minimum, value, Numeric)
    end

    def check_minimum(minimum, instance, _state, _data_type, _options, schema)
      if instance.is_a?(Numeric)
        if schema['exclusiveMinimum'].is_a?(TrueClass)
          raise_path_less_error "must be strictly greater than #{minimum}" if instance <= minimum
        else
          raise_path_less_error "expected to be minimum #{minimum}" if instance < minimum
        end
      end
    end

    def check_schema_exclusiveMinimum(value)
      _check_type(:exclusiveMinimum, value, Numeric, Boolean)
    end

    def check_exclusiveMinimum(minimum, instance)
      if minimum.is_a?(Numeric) && instance.is_a?(Numeric) && instance <= minimum
        raise_path_less_error "must be strictly greater than #{minimum}"
      end
    end

    # Validation Keywords for Strings

    def check_schema_maxLength(value)
      _check_type(:maxLength, value, Integer)
      raise_path_less_error "Invalid value for maxLength, a non negative value is expected" if value.negative?
    end

    def check_maxLength(value, instance)
      raise_path_less_error "is too long (#{instance.length} of #{value} max)" if instance.is_a?(String) && instance.length > value
    end

    def check_schema_minLength(value)
      _check_type(:maxLength, value, Integer)
      raise_path_less_error "Invalid value for minLength, a non negative value is expected" if value.negative?
    end

    def check_minLength(value, instance)
      raise_path_less_error "is too short (#{instance.length} of #{value} min)" if instance.is_a?(String) && instance.length < value
    end

    def check_schema_pattern(value)
      _check_type(:pattern, value, String)
      begin
        Regexp.new(value)
      rescue Exception => ex
        raise_path_less_error "Pattern value '#{value}' is not a regular expression: #{ex.message}"
      end
    end

    def check_pattern(value, instance)
      raise_path_less_error "does not match the pattern #{value}" if instance.is_a?(String) && !Regexp.new(value).match(instance)
    end

    FORMATS_MAP = {
      string: %w(date date-time time email hostname ipv4 ipv6 uri uuid url byte google-fieldmask),
      integer: %w(int32 uint32 int64 uint64),
      number: %w(float double long), # long format support for Accela Records API V4
      boolean: %w(toggle) # TODO: Remove when migrate UI semantics outside schemas
    }

    FORMATS = FORMATS_MAP.values.flatten

    def check_schema_format(format)
      _check_type(:format, format, String)
      raise_path_less_error "format #{format} is not supported" unless FORMATS.include?(format)
    end

    DATE_TIME_TYPES = [Date, DateTime, Time]

    HOSTNAME_REGEX = /^(([a-zA-Z0-9]|[a-zA-Z0-9][a-zA-Z0-9\-]*[a-zA-Z0-9])\.)*([A-Za-z0-9]|[A-Za-z0-9][A-Za-z0-9\-]*[A-Za-z0-9])$/

    UUID_REGEX = /[0-9a-fA-F]{8}\-[0-9a-fA-F]{4}\-[0-9a-fA-F]{4}\-[0-9a-fA-F]{4}\-[0-9a-fA-F]{12}/

    def check_format(format, instance, _state, _data_type, _options, schema)
      if instance
        if schema['type'] == 'string'
          check_string_format(format, instance)
        end

        if schema['type'] == 'integer' || schema['type'] == 'number'
          check_number_format(format, instance)
        end
      end
    end

    def check_string_format(format, instance)
      case format

      when 'date', 'date-time', 'time'
        unless DATE_TIME_TYPES.any? { |type| instance.is_a?(type) }
          begin
            DateTime.parse(instance)
          rescue Exception => ex
            raise_path_less_error "does not complies format #{format}: #{ex.message}"
          end
        end

      when 'email'
        _check_type(:email, instance, String)
        raise_path_less_error 'is not a valid email address' unless instance =~ URI::MailTo::EMAIL_REGEXP

      when 'ipv4'
        _check_type(:ipv4, instance, String)
        raise_path_less_error 'is not a valid IPv4' unless instance =~ ::Resolv::IPv4::Regex

      when 'ipv6'
        _check_type(:ipv6, instance, String)
        raise_path_less_error 'is not a valid IPv6' unless instance =~ ::Resolv::IPv6::Regex

      when 'hostname'
        _check_type(:'host name', instance, String)
        raise_path_less_error 'is not a valid host name' unless instance =~ HOSTNAME_REGEX

      when 'uri'
        _check_type(:URI, instance, String)
        begin
          URI.parse(instance)
        rescue Exception => ex
          raise_path_less_error "is not a valid URI"
        end

      when 'url'
        _check_type(:URL, instance, String)
        begin
          uri = URI.parse(instance)
          fail if uri.host.nil?
        rescue Exception => ex
          raise_path_less_error "is not a valid URL"
        end

      when 'uuid'
        _check_type(:UUID, instance, String)
        raise_path_less_error 'is not a valid UUID' unless instance =~ UUID_REGEX

      when 'byte'
        _check_type(:byte, instance, String)
        raise_path_less_error 'is not base64 encoded' unless Base64.encode64(Base64.decode64(instance)) == instance

      when 'google-fieldmask'
        #
        # Only for Google APIs support
        #
      else
        Tenant.notify(message: "JSON Schema format #{format} is not supported", type: :warning)
      end
    end

    INT32_MAX = 2 ** 31 - 1
    INT32_MIN = -(2 ** 31)

    UINT32_MAX = 2 ** 32 - 1
    UINT32_MIN = 0

    INT64_MAX = 2 ** 63 - 1
    INT64_MIN = -(2 ** 63)

    UINT64_MAX = 2 ** 64 - 1
    UINT64_MIN = 0

    FLOAT_MAX = (2 - 2 ** -23) * 2 ** 127
    FLOAT_MIN = -FLOAT_MAX

    DOUBLE_MAX = Float::MAX
    DOUBLE_MIN = Float::MIN

    NUMBER_RANGES = {
      int32: {
        min: INT32_MIN,
        max: INT32_MAX
      },

      uint32: {
        min: UINT32_MIN,
        max: UINT32_MAX
      },

      int64: {
        min: INT64_MIN,
        max: INT64_MAX
      },

      uint64: {
        min: UINT64_MIN,
        max: UINT64_MAX
      },

      float: {
        min: FLOAT_MIN,
        max: FLOAT_MAX
      },

      double: {
        min: DOUBLE_MIN,
        max: DOUBLE_MAX
      }
    }

    def check_number_format(format, instance)
      range = NUMBER_RANGES[format.to_s.to_sym]
      if range
        raise_path_less_error "is out of format #{format} range" if instance < range[:min] || instance > range[:max]
      else
        Tenant.notify(message: "JSON Schema format #{format} is not supported", type: :warning)
      end
    end

    # Keywords for Applying Subschemas to Arrays

    def check_schema_items(items_schema)
      _check_type(:items, items_schema, Hash, Array)
      if items_schema.is_a?(Hash)
        begin
          validate(items_schema)
        rescue Error => ex
          raise_path_less_error "Items schema is not valid: #{ex.message}"
        end
      else # Is an array
        errors = {}
        items_schema.each_with_index do |item_schema, index|
          begin
            validate(item_schema)
          rescue Error => ex
            errors[index] = ex.message
          end
        end
        unless errors.empty?
          msg = errors.map do |index, msg|
            "item schema ##{index} is not valid (#{msg})"
          end.to_sentence.capitalize
          raise_path_less_error msg
        end
      end
    end

    def check_items(items_schema, items, state, data_type, options)
      path = options[:path] || '#'
      if items.is_a?(Mongoff::RecordArray)
        items_schema = items.orm_model.schema
        data_type = items.orm_model.data_type
        has_errors = false
        items.each_with_index do |item, index|
          item.errors.clear
          begin
            validate_instance(item, options.merge(
              path: "#{path}[#{index}]",
              schema: items_schema,
              data_type: data_type
            ))
          rescue Error => ex
            _handle_error(item, ex)
          end
          has_errors ||= item.errors.present?
        end
        raise_soft 'has errors' if has_errors
      elsif items.is_a?(Array)
        if items_schema.is_a?(Array)
          items.each_with_index do |item, index|
            break unless index < items_schema.length
            begin
              validate_instance(item, options.merge(
                path: "#{path}[#{index}]",
                schema: items_schema[index],
                data_type: data_type
              ))
            rescue PathLessError => ex
              raise_error "Item #{path}[#{index}] #{ex.message}"
            end
          end
          state[:additional_items_index] = (items.length > items_schema.length) && items_schema.length
        else
          items_schema = data_type.merge_schema(items_schema)
          items.each_with_index do |item, index|
            begin
              validate_instance(item, options.merge(
                path: "#{path}[#{index}]",
                schema: items_schema,
                data_type: data_type
              ))
            rescue PathLessError => ex
              raise_error "Item #{path}[#{index}] #{ex.message}"
            end
          end
        end
      end
    end

    def check_schema_additionalItems(schema)
      begin
        validate(schema)
      rescue Error => ex
        raise_path_less_error "Additional items schema is not valid: #{ex.message}"
      end
    end

    def check_additionalItems(items_schema, items, state, data_type, options)
      if (start_index = state[:additional_items_index]) && start_index < items.length
        path = options[:path] || '#'
        items_schema = items_schema.is_a?(FalseClass) ? false : (items_schema || true)
        items_schema = data_type.merge_schema(items_schema)
        start_index.upto(items.length - 1) do |index|
          begin
            validate_instance(items[index], options.merge(
              path: "#{path}[#{index}]",
              schema: items_schema,
              data_type: data_type
            ))
          rescue PathLessError => ex
            raise_error "Item #{path}[#{index}] #{ex.message}"
          end
        end
      end
    end

    def check_schema_maxItems(max)
      _check_type(:maxItems, max, Integer)
      raise_path_less_error "Invalid value for maxItems, a non negative value is expected" if max.negative?
    end

    def check_maxItems(max, items)
      if items.is_a?(Mongoff::RecordArray) || items.is_a?(Array)
        raise_path_less_error "has too many items (#{items.count} of #{max} max)" if items.count > max
      end
    end

    def check_schema_minItems(min)
      _check_type(:minItems, min, Integer)
      raise_path_less_error "Invalid value for minItems, a non negative value is expected" if min.negative?
    end

    def check_minItems(min, items)
      if items.is_a?(Mongoff::RecordArray) || items.is_a?(Array)
        raise_path_less_error "has too few items (#{items.count} for #{min} min)" if items.count < min
      end
    end

    def check_schema_uniqueItems(unique)
      _check_type(:uniqueItems, unique, Boolean)
    end

    def check_uniqueItems(unique, items)
      if unique && (items.is_a?(Mongoff::RecordArray) || items.is_a?(Array))
        set = Set.new(items)
        raise_path_less_error 'contains repeated items' if set.count < items.count
      end
    end

    def check_schema_contains(schema)
      begin
        validate(schema)
      rescue Error => ex
        raise_path_less_error "Contains schema is not valid: #{ex.message}"
      end
    end

    def check_contains(contains_schema, items, state, data_type, options, schema)
      return unless items.is_a?(Mongoff::RecordArray) || items.is_a?(Array)
      contains_schema = data_type.merge_schema(contains_schema)
      data_type = items.orm_model.data_type if items.is_a?(Mongoff::RecordArray)
      max_min = schema['maxContains'] || schema['minContains']
      contains = 0
      items.each do |item|
        begin
          validate_instance(item, options.merge(
            schema: contains_schema,
            data_type: data_type
          ))
          contains += 1
          break unless max_min
        rescue
          next
        end
      end
      raise_path_less_error 'have no items matching the contains schema' if contains == 0
      state[:contains] = contains
    end

    def check_schema_maxContains(max)
      _check_type(:maxContains, max, Integer)
      raise_path_less_error "Invalid value for maxContains, a non negative value is expected" if max.negative?
    end

    def check_maxContains(max, _items, state)
      if (contains = state[:contains])
        raise_path_less_error "has too much items (#{contains} for #{max} max) matching the contains schema" if contains > max
      end
    end

    def check_schema_minContains(min)
      _check_type(:minContains, min, Integer)
      raise_path_less_error "Invalid value for minContains, a non negative value is expected" if min.negative?
    end

    def check_minContains(min, _items, state)
      if (contains = state[:contains])
        raise_path_less_error "has too few items (#{contains} for #{min} min) matching the contains schema" if contains < min
      end
    end

    # Keywords for Applying Subschemas to Objects

    def check_schema_required(value)
      _check_type(:properties, value, Array, Boolean) # TODO Boolean is only for legacy support
      if value.is_a?(Array)
        hash = {}
        value.each do |property_name|
          hash[property_name] = (hash[property_name] || 0) + 1
          _check_type('property name', property_name, String)
        end
        repeated_properties = hash.keys.select { |prop| hash[prop] > 1 }
        if repeated_properties.count > 0
          raise_path_less_error "Required properties are not unique: #{repeated_properties.to_sentence}"
        end
      else
        Tenant.notify(message: "JSON Schema keyword require is expected to be an Array and does not support #{value.class} values")
      end
    end

    def check_required(properties, instance)
      return unless instance && properties.is_a?(Array)
      if instance.is_a?(Mongoff::Record)
        has_errors = false
        stored_properties = instance.orm_model.stored_properties_on(instance)
        properties.each do |property|
          next if stored_properties.include?(property.to_s)
          has_errors = true
          _handle_error(instance, 'is required', property)
        end
        raise_soft 'has errors' if has_errors
      elsif instance.is_a?(Hash)
        required = properties.select do |property|
          !(instance.key?(property.to_s) || instance.key?(property.to_sym))
        end
        unless required.empty?
          if required.length == 1
            raise_path_less_error "Property #{required[0]} is required"
          end
          raise_path_less_error "Properties #{required.to_sentence} are required"
        end
      end
    end

    def check_schema_dependentRequired(value)
      _check_type(:dependentRequired, value, Hash)
      value.each do |property_name, dependencies|
        _check_type('property name', property_name, String, Symbol)
        _check_type('property dependencies', dependencies, Array)
        hash = {}
        dependencies.each do |prop|
          hash[prop.to_s] = (hash[prop.to_s] || 0) + 1
          _check_type('dependent property', prop, String, Symbol)
        end
        repeated_properties = hash.keys.select { |prop| hash[prop] > 1 }
        if repeated_properties.count > 0
          raise_path_less_error "Properties dependencies are not unique: #{repeated_properties.to_sentence}"
        end
      end
    end

    def check_dependentRequired(properties, instance)
      return unless instance
      if instance.is_a?(Mongoff::Record)
        has_errors = false
        stored_properties = instance.orm_model.stored_properties_on(instance).map(&:to_s)
        properties.each do |property, dependencies|
          next unless stored_properties.include?(property.to_s)
          dependencies.each do |dependent_property|
            unless stored_properties.include?(dependent_property.to_s)
              has_errors = true
              _handle_error(
                instance,
                "is required because depending on #{property}",
                dependent_property
              )
            end
          end
        end
        raise_soft 'has errors' if has_errors
      elsif instance.is_a?(Hash)
        hash = {}
        properties.each do |property, dependencies|
          next unless instance.key?(property.to_s) || instance.key?(property.to_sym)
          dependencies.each do |dependent_property|
            next if instance.key?(dependent_property.to_s) || instance.key?(dependent_property.to_sym)
            hash[property] = (hash[property] || []) + [dependent_property]
          end
        end
        unless hash.empty?
          error = hash.map do |property, dependents|
            if dependents.size > 1
              "properties #{dependents.to_sentence} are required because depending on #{property}"
            else
              "property #{dependents[0]} is required because depending on #{property}"
            end
          end.to_sentence.capitalize
          raise_path_less_error error
        end
      end
    end

    def check_schema_properties(value)
      _check_type(:properties, value, Hash)
      value.each do |property, schema|
        begin
          validate(schema)
        rescue RuntimeError => ex
          raise_path_less_error "Property #{property} schema is not valid: #{ex.message}"
        end
      end
    end

    def check_properties(properties, instance, state, data_type, options)
      path = options[:path] || '#'
      unless (checked_properties = state[:checked_properties])
        checked_properties = state[:checked_properties] = Set.new
      end
      if instance.is_a?(Mongoff::Record)
        unless state[:instance_clear]
          instance.errors.clear
          state[:instance_clear] = true
        end
        report_error = false
        if instance.changed?
          model = instance.orm_model
          model.stored_properties_on(instance).each do |property|
            next unless properties.key?(property)
            checked_properties << property.to_s
            begin
              property_data_type =
                if (property_model = model.property_model(property))
                  property_model.data_type
                else
                  data_type
                end
              validate_instance(instance[property], options.merge(
                path: "#{path}/#{property}",
                schema: model.property_schema(property),
                data_type: property_data_type
              ))
            rescue RuntimeError => ex
              _handle_error(instance, ex, property)
              report_error = true
            end
          end
        end
        raise_soft 'has errors' if report_error
      elsif instance.is_a?(Hash)
        instance.each do |property, value|
          property = property.to_s
          next unless properties.key?(property)
          checked_properties << property.to_s
          begin
            validate_instance(value, options.merge(
              path: "#{path}/#{property}",
              schema: properties[property],
              data_type: data_type
            ))
          rescue PathLessError => ex
            raise_error "Value '#{path}/#{property}' #{ex.message}"
          end
        end
      end
    end

    def check_schema_maxProperties(max)
      _check_type(:maxProperties, max, Integer)
      raise_path_less_error "Invalid value for maxProperties, a non negative value is expected" if max.negative?
    end

    def check_maxProperties(max, instance)
      if instance.is_a?(Mongoff::Record) || instance.is_a?(Hash)
        instance = instance.orm_model.stored_properties_on(instance) if instance.is_a?(Mongoff::Record)
        raise_path_less_error "has too many properties (#{instance.size} of #{max} max)" if instance.size > max
      end
    end

    def check_schema_minProperties(min)
      _check_type(:minProperties, min, Integer)
      raise_path_less_error "Invalid value for minProperties, a non negative value is expected" if min.negative?
    end

    def check_minProperties(min, instance)
      if instance.is_a?(Mongoff::Record) || instance.is_a?(Hash)
        instance = instance.orm_model.stored_properties_on(instance) if instance.is_a?(Mongoff::Record)
        raise_path_less_error "has too few properties (#{instance.size} for #{min} min)" if instance.size < min
      end
    end

    def check_schema_patternProperties(value)
      _check_type(:properties, value, Hash)
      value.each do |pattern, schema|
        begin
          Regexp.new(pattern.to_s)
        rescue Exception => ex
          raise_path_less_error "Property pattern #{pattern} is not a regex: #{ex.message}"
        end
        begin
          validate(schema)
        rescue Error => ex
          raise_path_less_error "Property pattern #{pattern} schema is not valid: #{ex.message}"
        end
      end
    end

    def check_patternProperties(patterns, instance, state, data_type, options)
      path = options[:path] || '#'
      unless (checked_properties = state[:checked_properties])
        checked_properties = state[:checked_properties] = Set.new
      end
      patterns = patterns.map { |pattern, schema| [Regexp.new(pattern), schema] }.to_h
      merged_schemas = {}
      if instance.is_a?(Mongoff::Record)
        unless state[:instance_clear]
          instance.errors.clear
          state[:instance_clear] = true
        end
        report_error = false
        if instance.changed?
          model = instance.orm_model
          model.stored_properties_on(instance).each do |property|
            pattern = patterns.keys.detect { |regex| regex.match(property) }
            next unless pattern
            checked_properties << property.to_s
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
              validate_instance(instance[property], options.merge(
                path: "#{path}/#{property}",
                schema: schema,
                data_type: property_data_type
              ))
            rescue RuntimeError => ex
              _handle_error(instance, ex, property)
              report_error = true
            end
          end
        end
        raise_soft 'has errors' if report_error
      elsif instance.is_a?(Hash)
        instance.each do |property, value|
          pattern = patterns.keys.detect { |regex| regex.match(property) }
          next unless pattern
          checked_properties << property.to_s
          unless (schema = merged_schemas[property])
            schema = merged_schemas[property] = data_type.merge_schema(patterns[pattern])
          end
          begin
            validate_instance(value, options.merge(
              path: "#{path}/#{property}",
              schema: schema,
              data_type: data_type
            ))
          rescue PathLessError => ex
            raise_error "Value '#{path}/#{property}' #{ex.message}"
          end
        end
      end
    end

    def check_schema_additionalProperties(schema)
      begin
        validate(schema)
      rescue Error => ex
        raise_path_less_error "Additional properties schema is not valid: #{ex.message}"
      end
    end

    def check_additionalProperties(schema, instance, state, data_type, options)
      path = options[:path] || '#'
      unless (checked_properties = state[:checked_properties])
        checked_properties = state[:checked_properties] = Set.new
      end
      schema = schema.is_a?(FalseClass) ? false : (schema || true)
      schema = data_type.merge_schema(schema)
      if instance.is_a?(Mongoff::Record)
        unless state[:instance_clear]
          instance.errors.clear
          state[:instance_clear] = true
        end
        report_error = false
        if instance.changed?
          model = instance.orm_model
          model.stored_properties_on(instance).each do |property|
            property = property.to_s
            next if checked_properties.include?(property) || property == '_id' || property == '_type'
            begin
              property_data_type =
                if (property_model = model.property_model(property))
                  property_model.data_type
                else
                  data_type
                end
              validate_instance(instance[property], options.merge(
                path: "#{path}/#{property}",
                schema: schema,
                data_type: property_data_type
              ))
            rescue RuntimeError => ex
              report_error = true
              _handle_error(instance, ex, property) do |msg|
                "#{msg} (against additional properties schema)"
              end
            end
          end
        end
        raise_soft 'has errors' if report_error
      elsif instance.is_a?(Hash)
        instance.each do |property, value|
          property = property.to_s
          next if checked_properties.include?(property) || property == '_id' || property == '_type'
          begin
            validate_instance(value, options.merge(
              path: "#{path}/#{property}",
              schema: schema,
              data_type: data_type
            ))
          rescue PathLessError => ex
            raise_error "Value '#{path}/#{property}' #{ex.message} (against additional properties schema)"
          end
        end
      end
    end

    def check_schema_propertyNames(schema)
      begin
        validate(schema)
      rescue Error => ex
        raise_path_less_error "Property names schema is not valid: #{ex.message}"
      end
    end

    def check_propertyNames(schema, instance, state, data_type, options)
      path = options[:path] || '#'
      schema = data_type.merge_schema(schema)
      if instance.is_a?(Mongoff::Record)
        unless state[:instance_clear]
          instance.errors.clear
          state[:instance_clear] = true
        end
        report_error = false
        if instance.changed?
          model = instance.orm_model
          model.stored_properties_on(instance).each do |property|
            begin
              validate_instance(property, options.merge(
                path: "#{path}/#{property}",
                schema: schema,
                data_type: data_type
              ))
            rescue RuntimeError => ex
              report_error = true
              _handle_error(instance, ex, property) do |msg|
                "name does not match the property names schema: #{msg}"
              end
            end
          end
        end
        raise_soft 'has errors' if report_error
      elsif instance.is_a?(Hash)
        instance.keys.each do |property|
          begin
            validate_instance(property, options.merge(
              path: "#{path}/#{property}",
              schema: schema,
              data_type: data_type
            ))
          rescue PathLessError => ex
            raise_path_less_error "Property '#{path}/#{property}' name does not match property names schema: #{ex.message}"
          end
        end
      end
    end

    # Keywords for Applying Subschemas With Boolean Logic

    def check_schema_allOf(schemas)
      _check_type(:allOf, schemas, Array)
      raise_path_less_error 'allOf schemas should not be empty' if schemas.length == 0
      schemas.each_with_index do |schema, index|
        begin
          validate(schema)
        rescue Error => ex
          raise_path_less_error "allOf schema##{index} is not valid: #{ex.message}"
        end
      end
    end

    def check_allOf(schemas, instance, _, data_type)
      schemas.each_with_index do |schema, index|
        begin
          validate_instance(instance, schema: schema, data_type: data_type)
        rescue Error => ex
          raise_path_less_error "does not match allOf schema##{index}: #{ex.message}"
        end
      end
    end

    def check_schema_anyOf(schemas)
      _check_type(:anyOf, schemas, Array)
      raise_path_less_error 'anyOf schemas should not be empty' if schemas.length == 0
      schemas.each_with_index do |schema, index|
        begin
          validate(schema)
        rescue Error => ex
          raise_path_less_error "anyOf schema##{index} is not valid: #{ex.message}"
        end
      end
    end

    def check_anyOf(schemas, instance, _, data_type)
      schemas.each_with_index do |schema|
        begin
          validate_instance(instance, schema: schema, data_type: data_type)
          return
        rescue
        end
      end
      raise_path_less_error 'does not match any of the anyOf schemas'
    end

    def check_schema_oneOf(schemas)
      _check_type(:oneOf, schemas, Array)
      raise_path_less_error 'oneOf schemas should not be empty' if schemas.length == 0
      schemas.each_with_index do |schema, index|
        begin
          validate(schema)
        rescue Error => ex
          raise_path_less_error "oneOf schema##{index} is not valid: #{ex.message}"
        end
      end
    end

    def check_oneOf(schemas, instance, _, data_type)
      one_index = nil
      schemas.each_with_index do |schema, index|
        valid =
          begin
            validate_instance(instance, schema: schema, data_type: data_type)
            true
          rescue
            false
          end
        if valid
          if one_index
            raise_path_less_error "match more than one oneOf schemas (at least ##{one_index} and ##{index})"
          else
            one_index = index
          end
        end
      end
      raise_path_less_error 'does not match any of the oneOf schemas' unless one_index
    end

    def check_schema_not(schema)
      begin
        validate(schema)
      rescue Error => ex
        raise_path_less_error "Not schema is not valid: #{ex.message}"
      end
    end

    def check_not(schema, instance, _, data_type)
      begin
        validate_instance(instance, schema: schema, data_type: data_type)
      rescue
        return
      end
      raise_path_less_error "should not match a NOT schema"
    end

    # Keywords for Applying Subschemas Conditionally

    def check_schema_if(schema)
      begin
        validate(schema)
      rescue Error => ex
        raise_path_less_error "If schema is not valid: #{ex.message}"
      end
    end

    def check_if(schema, instance, state, data_type)
      success =
        begin
          validate_instance(instance, schema: schema, data_type: data_type)
          true
        rescue
          false
        end
      state[:if_success] = success
    end

    def check_schema_then(schema)
      begin
        validate(schema)
      rescue Error => ex
        raise_path_less_error "Then schema is not valid: #{ex.message}"
      end
    end

    def check_then(schema, instance, state, data_type)
      if state.key?(:if_success) && state[:if_success]
        begin
          validate_instance(instance, schema: schema, data_type: data_type)
        rescue
          raise_path_less_error "matches the IF schema but it does not match the THEN one"
        end
      end
    end

    def check_schema_else(schema)
      begin
        validate(schema)
      rescue Error => ex
        raise_path_less_error "Else schema is not valid: #{ex.message}"
      end
    end

    def check_else(schema, instance, state, data_type)
      if state.key?(:if_success) && !state[:if_success]
        begin
          validate_instance(instance, schema: schema, data_type: data_type)
        rescue
          raise_path_less_error "does not match the IF schema and does not match the ELSE one"
        end
      end
    end

    def check_schema_dependentSchemas(properties)
      _check_type(:dependentSchemas, properties, Hash)
      properties.each do |property_name, dependent_schema|
        begin
          validate(dependent_schema)
        rescue Error => ex
          raise_path_less_error "Dependent schema en property #{property_name} is not valid: #{ex.message}"
        end
      end
    end

    def check_dependentSchemas(properties, instance, _, data_type)
      return unless instance
      if instance.is_a?(Mongoff::Record)
        has_errors = false
        stored_properties = instance.orm_model.stored_properties_on(instance).map(&:to_s)
        properties.each do |property, dependent_schema|
          next unless stored_properties.include?(property.to_s)
          begin
            validate_instance(instance, schema: dependent_schema, data_type: data_type)
          rescue Error => ex
            has_errors = true
            _handle_error(
              instance,
              "Does not match dependent schema on property #{property} (#{ex.message})",
            )
          end
        end
        raise_path_less_error 'has errors' if has_errors
      elsif instance.is_a?(Hash)
        dependent_properties = {}
        properties.each do |property, dependent_schema|
          next unless instance.key?(property.to_s) || instance.key?(property.to_sym)
          begin
            validate_instance(instance, schema: dependent_schema, data_type: data_type)
          rescue Error => ex
            dependent_properties[property] = ex.message
          end
        end
        unless dependent_properties.empty?
          error = dependent_properties.map do |property, msg|
            "does not match dependent schema on property #{property} (#{msg})"
          end.to_sentence.capitalize
          raise_path_less_error error
        end
      end
    end

    # Utilities

    def _check_type(key, value, *klasses)
      unless klasses.any? { |klass| value.is_a?(klass) }
        raise_path_less_error "Invalid value for #{key} of type #{value.class} (#{value}), #{klasses.to_sentence(last_word_connector: 'or')} is expected"
      end
    end

    def _handle_error(instance, err, property = :base)
      return unless instance
      msg = err.is_a?(String) ? err : err.message
      if block_given?
        msg = yield msg
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

    def raise_soft(msg)
      raise SoftError, msg
    end

    def raise_path_less_error(msg)
      raise PathLessError, msg
    end

    def raise_error(msg)
      raise Error, msg
    end

    class Error < RuntimeError

    end

    class PathLessError < Error

    end

    class SoftError < Error

    end
  end
end
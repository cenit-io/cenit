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
    rescue SoftError => err
      if instance.errors.blank?
        instance.errors.add(:base, err.message.capitalize)
      end
    rescue Exception => ex
      instance.errors.add(:base, ex.message.capitalize)
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

    # Utilities

    def _check_type(key, value, *klasses)
      unless klasses.any? { |klass| value.is_a?(klass) }
        raise "Invalid value for #{key} of type #{value.class} (#{value}), #{klass.to_sentence(last_word_connector: 'or')} is expected"
      end
    end

    class SoftError < RuntimeError

    end
  end
end
require 'spec_helper'

describe Mongoff::Validator do

  test_namespace = 'Mongoff Validator Test'

  test_schema = {
    type: 'object',
    properties: properties = {
      id: {
        # TODO If not declared then parsed id from JSON is ignored (fix it!)
      },
      null: {
        type: 'null'
      },
      boolean: {
        type: 'boolean'
      },
      integer: {
        type: 'integer'
      },
      number: {
        type: 'number'
      },
      string: {
        type: 'string'
      },
      obj: {
        type: 'object'
      },
      array: {
        type: 'array'
      },

      color: {
        enum: enum = %w(red green blue)
      },

      const: const_schema = {
        const: rand(100)
      }.deep_stringify_keys,

      multipleOf: multiple_of_schema = {
        type: 'number',
        multipleOf: multiple_of = 5 + rand(10)
      },

      minimum: minimum_schema = {
        type: 'number',
        minimum: 5 + rand(100)
      }.stringify_keys,

      maximum: maximum_schema = {
        type: 'number',
        maximum: minimum_schema['minimum'] + 10 + rand(100)
      }.deep_stringify_keys,


      exclusiveMaximum: {
        type: 'number',
        exclusiveMaximum: exclusive_maximum = 100 + rand(100)
      },

      exclusiveMinimum: {
        type: 'number',
        exclusiveMinimum: exclusive_minimum = 100 - rand(100)
      },

      maxLength: {
        type: 'string',
        maxLength: max_length = 10 + rand(50)
      },

      minLength: {
        type: 'string',
        minLength: min_length = 10 + rand(10)
      },

      pattern: {
        type: 'string',
        pattern: '\S+@\S+\.\S+'
      },

      date: {
        type: 'string',
        format: 'date'
      },

      time: {
        type: 'string',
        format: 'time'
      },

      date_time: {
        type: 'string',
        format: 'date-time'
      },

      email: email_schema = {
        type: 'string',
        format: 'email'
      },

      ipv4: {
        type: 'string',
        format: 'ipv4'
      },

      ipv6: {
        type: 'string',
        format: 'ipv6'
      },

      hostname: {
        type: 'string',
        format: 'hostname'
      },

      uri: {
        type: 'string',
        format: 'uri'
      },

      uuid: {
        type: 'string',
        format: 'uuid'
      },

      embedded_array: {
        type: 'array',
        items: {
          '$ref': 'A'
        }
      },

      array_ref: {
        type: 'array',
        referenced: true,
        items: {
          '$ref': 'A'
        }
      },

      embedded_array_items: {
        type: 'array',
        items: [
          const_schema,
          { '$ref': 'A' }
        ]
      },

      embedded_additionalItems: {
        type: 'array',
        items: [
          const_schema,
          { '$ref': 'A' }
        ],
        additionalItems: maximum_schema
      },

      embedded_maxItems: max_items_schema = {
        type: 'array',
        maxItems: 5 + rand(10)
      }.stringify_keys,

      ref_maxItems: max_items_schema.merge(
        items: { '$ref': 'A' },
        referenced: true
      ).stringify_keys,

      embedded_minItems: min_items_schema = {
        type: 'array',
        minItems: 5 + rand(10)
      }.stringify_keys,

      ref_minItems: min_items_schema.merge(
        items: { '$ref': 'A' },
        referenced: true
      ).stringify_keys,

      embedded_uniqueItems: {
        type: 'array',
        uniqueItems: true
      },

      embedded_not_uniqueItems: {
        type: 'array',
        uniqueItems: false
      },

      embedded_contains: {
        type: 'array',
        contains: const_schema
      },

      ref_contains: {
        type: 'array',
        items: {
          '$ref': 'A'
        },
        contains: {
          '$ref': 'A',
          required: %w(const)
        }
      },

      maxContains: {
        type: 'array',
        contains: const_schema,
        maxContains: max_contains = 5 + rand(10)
      },

      minContains: {
        type: 'array',
        contains: const_schema,
        minContains: min_contains = 10 + rand(5)
      },

      embedded_properties: {
        '$ref': 'A'
      },

      ref_properties: {
        referenced: true,
        '$ref': 'A'
      },

      embedded_array_properties: {
        type: 'array',
        items: {
          '$ref': 'A'
        }
      },

      ref_array_properties: {
        referenced: true,
        type: 'array',
        items: {
          '$ref': 'A'
        }
      },

      embedded_maxProperties: {
        type: 'object',
        maxProperties: max_properties = 14
      },

      ref_maxProperties: {
        '$ref': 'A',
        referenced: true,
        maxProperties: max_properties
      },

      embedded_minProperties: {
        type: 'object',
        minProperties: min_properties = 7
      },

      ref_minProperties: {
        '$ref': 'A',
        referenced: true,
        minProperties: min_properties
      },

      allOf: {
        allOf: [
          minimum_schema,
          maximum_schema
        ]
      },

      anyOf: {
        anyOf: [
          multiple_of_schema,
          maximum_schema
        ]
      }
    },

    patternProperties: {
      '[a-z]*_email': email_schema,

      "not_allowed(_\\d)?": false,

      "allowed_\\d": true
    },

    additionalProperties: const_schema,

    propertyNames: {
      maxLength: property_names_max_length = 20 + properties.keys.map(&:to_s).map(&:length).max
    }
  }.deep_stringify_keys

  sample = {
    null: nil,

    boolean: true,

    integer: 10 + rand(10),

    number: 10 + rand(10) + rand,

    string: 'string',

    obj: {},

    array: [],

    color: enum.take(1)[0],

    const: const_schema['const'],

    multipleOf: (1 + rand(10)) * multiple_of,

    maximum: maximum_schema['maximum'],

    minimum: minimum_schema['minimum'],

    exclusiveMaximum: exclusive_maximum - 1,

    exclusiveMinimum: exclusive_minimum + 1,

    maxLength: 'a' * max_length,

    minLength: 'a' * min_length,

    pattern: 'support@cenit.io',

    date: Time.now,

    time: Time.now,

    date_time: Time.now,

    email: 'support@cenit.io'
  }

  required_test_schema = {
    required: required_props = sample.keys.take(2 + rand(5)).map(&:to_s) - %w(null)
  }.deep_stringify_keys

  required_test_schema = test_schema.deep_merge(required_test_schema)

  dependent_required_test_schema = {
    dependentRequired: {
      (p_0 = sample.keys[1]) => [p_1 = sample.keys[2]],
      (p_2 = sample.keys[3]) => [p_3 = sample.keys[4], p_4 = sample.keys[5]]
    }
  }.deep_stringify_keys

  dependent_required_test_schema = test_schema.deep_merge(dependent_required_test_schema)

  additional_properties_true_schema = test_schema.merge(additionalProperties: true)

  additional_properties_false_schema = test_schema.merge(additionalProperties: false)

  before :all do
    Setup::JsonDataType.create!(
      namespace: test_namespace,
      name: 'A',
      schema: test_schema
    )

    Setup::JsonDataType.create!(
      namespace: test_namespace,
      name: 'R',
      schema: required_test_schema
    )

    Setup::JsonDataType.create!(
      namespace: test_namespace,
      name: 'dR',
      schema: dependent_required_test_schema
    )

    Setup::JsonDataType.create!(
      namespace: test_namespace,
      name: 'addTrue',
      schema: additional_properties_true_schema
    )

    Setup::JsonDataType.create!(
      namespace: test_namespace,
      name: 'addFalse',
      schema: additional_properties_false_schema
    )
  end

  let! :validator do
    ::Mongoff::Validator
  end

  let! :data_type do
    Setup::DataType.where(namespace: test_namespace, name: 'A').first
  end

  let! :data_type_with_required do
    Setup::DataType.where(namespace: test_namespace, name: 'R').first
  end

  let! :data_type_with_dependent_required do
    Setup::DataType.where(namespace: test_namespace, name: 'dR').first
  end

  let! :data_type_with_additional_props_true do
    Setup::DataType.where(namespace: test_namespace, name: 'addTrue').first
  end

  let! :data_type_with_additional_props_false do
    Setup::DataType.where(namespace: test_namespace, name: 'addFalse').first
  end

  let! :test_schema do
    data_type.schema
  end

  let :sample_instance do
    sample.clone
  end

  context 'when validating a schema' do

    it 'returns true if the schema is valid' do
      expect(validator.is_valid?(test_schema)).to be true
    end

    it 'returns false if the schema is not valid' do
      expect(validator.is_valid?('not valid schema')).to be false
    end

    it 'provides check schema logic for every validation keyword' do
      not_checked_keywords = ::Mongoff::Validator::INSTANCE_VALIDATION_KEYWORDS.select do |keyword|
        !validator.respond_to?("check_schema_#{keyword}")
      end
      expect(not_checked_keywords).to match_array([])
    end

    context 'when validating Boolean JSON Schemas' do

      it 'returns true if the schema is the true value' do
        expect(validator.is_valid?(true)).to be true
      end

      it 'returns true if the schema is the false value' do
        expect(validator.is_valid?(true)).to be true
      end
    end

    context 'when validating Keywords for Any Instance Type' do

      context 'when validating keyword type' do

        it 'does not raise an exception if the type value is a primitive type' do
          %w(null boolean object array number string integer).each do |primitive_type|
            schema = { type: primitive_type }
            expect { validator.validate(schema) }.not_to raise_error
          end
        end

        it 'raises an exception if the type value is not a primitive type' do
          schema = { type: 'not a primitive type' }
          expect { validator.validate(schema) }.to raise_error(::Mongoff::Validator::Error)
        end
      end

      context 'when validating keyword enum' do

        it 'does not raise an exception if the enum value is valid' do
          schema = { enum: %w(a b c) }
          expect { validator.validate(schema) }.not_to raise_error
        end

        it 'raises an exception if the enum value is not an array' do
          schema = { enum: 'not a array' }
          expect { validator.validate(schema) }.to raise_error(::Mongoff::Validator::Error)
        end

        it 'raises an exception if the enum value is an empty array' do
          schema = { enum: [] }
          expect { validator.validate(schema) }.to raise_error(::Mongoff::Validator::Error)
        end

        it 'raises an exception if the enum elements are not unique' do
          schema = { enum: [1, 2, 2, 3] }
          expect { validator.validate(schema) }.to raise_error(::Mongoff::Validator::Error)
        end
      end

      context 'when validating keyword const' do

        it 'raises an exception if the const value is not a JSON value' do
          schema = { const: validator }
          expect { validator.validate(schema) }.to raise_error(::Mongoff::Validator::Error)
        end
      end
    end

    context 'when validating Keywords for Numeric Instances' do

      context 'when validating keyword multipleOf' do

        it 'does not raise an exception if the multipleOf value is a number strictly grater than zero' do
          schema = { multipleOf: rand(100) + 0.1 }
          expect { validator.validate(schema) }.not_to raise_error
        end

        it 'raises an exception if the multipleOf value is not a number' do
          schema = { multipleOf: 'not a number' }
          expect { validator.validate(schema) }.to raise_error(::Mongoff::Validator::Error)
        end

        it 'raises an exception if the multipleOf value is not strictly grater than zero' do
          schema = { multipleOf: -rand(100) - 0.1 }
          expect { validator.validate(schema) }.to raise_error(::Mongoff::Validator::Error)
        end
      end

      context 'when validating keyword maximum' do

        it 'does not raise an exception if the maximum value is a number' do
          schema = { maximum: rand(100) }
          expect { validator.validate(schema) }.not_to raise_error
        end

        it 'raises an exception if the maximum value is not a number' do
          schema = { maximum: 'not a number' }
          expect { validator.validate(schema) }.to raise_error(::Mongoff::Validator::Error)
        end
      end

      context 'when validating keyword exclusiveMaximum' do

        it 'does not raise an exception if the exclusiveMaximum value is a number' do
          schema = { exclusiveMaximum: rand(100) }
          expect { validator.validate(schema) }.not_to raise_error
        end

        it 'raises an exception if the exclusiveMaximum value is not a number' do
          schema = { exclusiveMaximum: 'not a number' }
          expect { validator.validate(schema) }.to raise_error(::Mongoff::Validator::Error)
        end
      end

      context 'when validating keyword minimum' do

        it 'does not raise an exception if the minimum value is a number' do
          schema = { minimum: rand(100) }
          expect { validator.validate(schema) }.not_to raise_error
        end

        it 'raises an exception if the minimum value is not a number' do
          schema = { minimum: 'not a number' }
          expect { validator.validate(schema) }.to raise_error(::Mongoff::Validator::Error)
        end
      end

      context 'when validating keyword exclusiveMinimum' do

        it 'does not raise an exception if the exclusiveMaximum value is a number' do
          schema = { exclusiveMinimum: rand(100) }
          expect { validator.validate(schema) }.not_to raise_error
        end

        it 'raises an exception if the exclusiveMaximum value is not a number' do
          schema = { exclusiveMinimum: 'not a number' }
          expect { validator.validate(schema) }.to raise_error(::Mongoff::Validator::Error)
        end
      end
    end

    context 'when validating Keywords for Strings' do

      context 'when validating keyword maxLength' do

        it 'does not raise an exception if the maxLength value is a non negative integer' do
          schema = { maxLength: rand(100) }
          expect { validator.validate(schema) }.not_to raise_error
        end

        it 'raises an exception if the maxLength value is not an integer' do
          schema = { maxLength: 1 + rand }
          expect { validator.validate(schema) }.to raise_error(::Mongoff::Validator::Error)
        end

        it 'raises an exception if the maxLength value is a negative integer' do
          schema = { maxLength: -1 - rand(100) }
          expect { validator.validate(schema) }.to raise_error(::Mongoff::Validator::Error)
        end
      end

      context 'when validating keyword minLength' do

        it 'does not raise an exception if the minLength value is a non negative integer' do
          schema = { minLength: rand(100) }
          expect { validator.validate(schema) }.not_to raise_error
        end

        it 'raises an exception if the minLength value is not an integer' do
          schema = { minLength: 1 + rand }
          expect { validator.validate(schema) }.to raise_error(::Mongoff::Validator::Error)
        end

        it 'raises an exception if the minLength value is a negative integer' do
          schema = { minLength: -1 - rand(100) }
          expect { validator.validate(schema) }.to raise_error(::Mongoff::Validator::Error)
        end
      end

      context 'when validating keyword pattern' do

        it 'does not raise an exception if the pattern value is a regular expression' do
          schema = { pattern: '^(\\([0-9]{3}\\))?[0-9]{3}-[0-9]{4}$' }
          expect { validator.validate(schema) }.not_to raise_error
        end

        it 'raises an exception if the pattern value is not a string' do
          schema = { pattern: true }
          expect { validator.validate(schema) }.to raise_error(::Mongoff::Validator::Error)
        end

        it 'raises an exception if the pattern value is not regular expression' do
          schema = { pattern: 'not a regular (expression]' }
          expect { validator.validate(schema) }.to raise_error(::Mongoff::Validator::Error)
        end
      end

      context 'when validating defined formats' do

        it 'does not raise an exception if the format value is a valid' do
          ::Mongoff::Validator::FORMATS.each do |format|
            schema = { format: format }
            expect { validator.validate(schema) }.not_to raise_error
          end
        end

        it 'raises an exception if the format value is not valid' do
          schema = { format: 'not valid format' }
          expect { validator.validate(schema) }.to raise_error(::Mongoff::Validator::Error)
        end
      end
    end

    context 'when validating keywords for Applying Subschemas to Arrays' do

      context 'when validating keyword items' do

        it 'does not raise an exception if the items value is a valid schema' do
          schema = { items: test_schema }
          expect { validator.validate(schema) }.not_to raise_error
        end

        it 'does not raise an exception if the items value is an array of valid schemas' do
          schema = { items: Array.new(1 + rand(3), test_schema) }
          expect { validator.validate(schema) }.not_to raise_error
        end

        it 'raises an exception if the items value is an invalid schema' do
          schema = { items: 'not valid schema' }
          expect { validator.validate(schema) }.to raise_error(::Mongoff::Validator::Error)
        end

        it 'raises an exception if the items value is an array containing not valid schemas' do
          schema = { items: ['not valid schema', test_schema, 'not valid schema'] }
          expect { validator.validate(schema) }.to raise_error(::Mongoff::Validator::Error)
        end
      end

      context 'when validating keyword additionalItems' do

        it 'does not raise an exception if the additionalItems value is a valid schema' do
          schema = { additionalItems: test_schema }
          expect { validator.validate(schema) }.not_to raise_error
        end

        it 'raises an exception if the additionalItems value is not a valid schema' do
          schema = { items: 'not valid schema' }
          expect { validator.validate(schema) }.to raise_error(::Mongoff::Validator::Error)
        end
      end

      context 'when validating keyword maxItems' do

        it 'does not raise an exception if the maxItems value is a non negative integer' do
          schema = { maxItems: rand(100) }
          expect { validator.validate(schema) }.not_to raise_error
        end

        it 'raises an exception if the maxItems value is not an integer' do
          schema = { maxItems: 1 + rand }
          expect { validator.validate(schema) }.to raise_error(::Mongoff::Validator::Error)
        end

        it 'raises an exception if the maxItems value is a negative integer' do
          schema = { maxItems: -1 - rand(100) }
          expect { validator.validate(schema) }.to raise_error(::Mongoff::Validator::Error)
        end
      end

      context 'when validating keyword minItems' do

        it 'does not raise an exception if the minItems value is a non negative integer' do
          schema = { minItems: rand(100) }
          expect { validator.validate(schema) }.not_to raise_error
        end

        it 'raises an exception if the minItems value is not an integer' do
          schema = { minItems: 1 + rand }
          expect { validator.validate(schema) }.to raise_error(::Mongoff::Validator::Error)
        end

        it 'raises an exception if the minItems value is a negative integer' do
          schema = { minItems: -1 - rand(100) }
          expect { validator.validate(schema) }.to raise_error(::Mongoff::Validator::Error)
        end
      end

      context 'when validating keyword uniqueItems' do

        it 'does not raise an exception if the uniqueItems value is a boolean' do
          schema = { uniqueItems: rand(2).to_b }
          expect { validator.validate(schema) }.not_to raise_error
        end

        it 'raises an exception if the uniqueItems value is not a boolean' do
          schema = { uniqueItems: 'not a boolean' }
          expect { validator.validate(schema) }.to raise_error(::Mongoff::Validator::Error)
        end
      end

      context 'when validating keyword contains' do

        it 'does not raise an exception if contains is a valid schema' do
          schema = { contains: test_schema }
          expect { validator.validate(schema) }.not_to raise_error
        end

        it 'raises an exception if the contains schema not valid' do
          schema = { contains: 'not valid schema' }
          expect { validator.validate(schema) }.to raise_error(::Mongoff::Validator::Error)
        end
      end

      context 'when validating keyword maxContains' do

        it 'does not raise an exception if the maxContains value is a non negative integer' do
          schema = { maxContains: rand(100) }
          expect { validator.validate(schema) }.not_to raise_error
        end

        it 'raises an exception if the maxContains value is not an integer' do
          schema = { maxContains: 1 + rand }
          expect { validator.validate(schema) }.to raise_error(::Mongoff::Validator::Error)
        end

        it 'raises an exception if the maxContains value is a negative integer' do
          schema = { maxContains: -1 - rand(100) }
          expect { validator.validate(schema) }.to raise_error(::Mongoff::Validator::Error)
        end
      end

      context 'when validating keyword minContains' do

        it 'does not raise an exception if the minContains value is a non negative integer' do
          schema = { minContains: rand(100) }
          expect { validator.validate(schema) }.not_to raise_error
        end

        it 'raises an exception if the minContains value is not an integer' do
          schema = { minContains: 1 + rand }
          expect { validator.validate(schema) }.to raise_error(::Mongoff::Validator::Error)
        end

        it 'raises an exception if the minContains value is a negative integer' do
          schema = { minContains: -1 - rand(100) }
          expect { validator.validate(schema) }.to raise_error(::Mongoff::Validator::Error)
        end
      end
    end

    context 'when validating keywords for Applying Subschemas to Objects' do

      context 'when validating keyword properties' do

        it 'does not raise an exception if the properties value is valid' do
          schema = { properties: { value: maximum_schema } }
          expect { validator.validate(schema) }.not_to raise_error
        end

        it 'raises an exception if the properties value is not an object' do
          schema = { properties: 'not a object' }
          expect { validator.validate(schema) }.to raise_error(::Mongoff::Validator::Error)
        end

        it 'raises an exception if a properties entry value is not a valid schema' do
          schema = {
            properties: {
              value: maximum_schema,
              wrong: 'not a valid schema'
            }
          }
          expect { validator.validate(schema) }.to raise_error(::Mongoff::Validator::Error)
        end
      end

      context 'when validating keyword patternProperties' do

        it 'does not raise an exception if the patternProperties value is valid' do
          schema = { patternProperties: { '[a-z]*_email': email_schema } }
          expect { validator.validate(schema) }.not_to raise_error
        end

        it 'raises an exception if the patternProperties value is not an object' do
          schema = { patternProperties: 'not a object' }
          expect { validator.validate(schema) }.to raise_error(::Mongoff::Validator::Error)
        end

        it 'raises an exception if a patternProperties entry is not a regular expression' do
          schema = {
            patternProperties: {
              '[a-z]*_email': email_schema,
              'not a regular (expression]': {}
            }
          }
          expect { validator.validate(schema) }.to raise_error(::Mongoff::Validator::Error)
        end

        it 'raises an exception if a patternProperties entry value is not a valid schema' do
          schema = {
            patternProperties: {
              '[a-z]*_email': 'not a valid schema'
            }
          }
          expect { validator.validate(schema) }.to raise_error(::Mongoff::Validator::Error)
        end
      end

      context 'when validating keyword additionalProperties' do

        it 'does not raise an exception if additionalProperties is a valid schema' do
          schema = { additionalProperties: test_schema }
          expect { validator.validate(schema) }.not_to raise_error
        end

        it 'raises an exception if the additionalProperties schema not valid' do
          schema = { additionalProperties: 'not valid schema' }
          expect { validator.validate(schema) }.to raise_error(::Mongoff::Validator::Error)
        end
      end

      context 'when validating keyword maxProperties' do

        it 'does not raise an exception if the maxProperties value is a non negative integer' do
          schema = { maxProperties: rand(100) }
          expect { validator.validate(schema) }.not_to raise_error
        end

        it 'raises an exception if the maxProperties value is not an integer' do
          schema = { maxProperties: 1 + rand }
          expect { validator.validate(schema) }.to raise_error(::Mongoff::Validator::Error)
        end

        it 'raises an exception if the maxProperties value is a negative integer' do
          schema = { maxProperties: -1 - rand(100) }
          expect { validator.validate(schema) }.to raise_error(::Mongoff::Validator::Error)
        end
      end

      context 'when validating keyword minProperties' do

        it 'does not raise an exception if the minProperties value is a non negative integer' do
          schema = { minProperties: rand(100) }
          expect { validator.validate(schema) }.not_to raise_error
        end

        it 'raises an exception if the minProperties value is not an integer' do
          schema = { minProperties: 1 + rand }
          expect { validator.validate(schema) }.to raise_error(::Mongoff::Validator::Error)
        end

        it 'raises an exception if the minProperties value is a negative integer' do
          schema = { minProperties: -1 - rand(100) }
          expect { validator.validate(schema) }.to raise_error(::Mongoff::Validator::Error)
        end
      end

      context 'when validating keyword required' do

        it 'does not raise an exception if the required value is valid' do
          schema = { required: %w(a b c) }
          expect { validator.validate(schema) }.not_to raise_error
        end

        it 'raises an exception if the required value is not an array' do
          schema = { required: 'not a array' }
          expect { validator.validate(schema) }.to raise_error(::Mongoff::Validator::Error)
        end

        it 'raises an exception if the required elements are not unique' do
          schema = { required: %w(a b b c) }
          expect { validator.validate(schema) }.to raise_error(::Mongoff::Validator::Error)
        end
      end

      context 'when validating keyword dependentRequired' do

        it 'does not raise an exception if the dependentRequired value is valid' do
          schema = {
            dependentRequired: {
              a: %w(b c),
              b: %w(a c)
            }
          }
          expect { validator.validate(schema) }.not_to raise_error
        end

        it 'raises an exception if the dependentRequired value is not an object' do
          schema = { dependentRequired: 'not a object' }
          expect { validator.validate(schema) }.to raise_error(::Mongoff::Validator::Error)
        end

        it 'raises an exception if the dependentRequired properties are not arrays' do
          schema = {
            dependentRequired: {
              a: 'not an array'
            }
          }
          expect { validator.validate(schema) }.to raise_error(::Mongoff::Validator::Error)
        end

        it 'raises an exception if the dependentRequired properties are not string arrays' do
          schema = {
            dependentRequired: {
              a: ['b', 0]
            }
          }
          expect { validator.validate(schema) }.to raise_error(::Mongoff::Validator::Error)
        end

        it 'raises an exception if the dependentRequired properties are not unique string arrays' do
          schema = {
            dependentRequired: {
              a: %w(b b c)
            }
          }
          expect { validator.validate(schema) }.to raise_error(::Mongoff::Validator::Error)
        end
      end
    end

    context 'when validating Keywords for Applying Subschemas With Boolean Logic' do

      context 'when validating keyword allOf' do

        it 'does not raise an exception if the allOf value is valid' do
          schema = { allOf: Array.new(1 + rand(3), test_schema) }
          expect { validator.validate(schema) }.not_to raise_error
        end

        it 'raises an exception if the allOf value is not an array' do
          schema = { allOf: 'not a array' }
          expect { validator.validate(schema) }.to raise_error(::Mongoff::Validator::Error)
        end

        it 'raises an exception if the allOf value is an empty array' do
          schema = { allOf: [] }
          expect { validator.validate(schema) }.to raise_error(::Mongoff::Validator::Error)
        end
      end

      context 'when validating keyword anyOf' do

        it 'does not raise an exception if the anyOf value is valid' do
          schema = { anyOf: Array.new(1 + rand(3), test_schema) }
          expect { validator.validate(schema) }.not_to raise_error
        end

        it 'raises an exception if the anyOf value is not an array' do
          schema = { anyOf: 'not a array' }
          expect { validator.validate(schema) }.to raise_error(::Mongoff::Validator::Error)
        end

        it 'raises an exception if the anyOf value is an empty array' do
          schema = { anyOf: [] }
          expect { validator.validate(schema) }.to raise_error(::Mongoff::Validator::Error)
        end
      end

      context 'when validating keyword oneOf' do

        it 'does not raise an exception if the oneOf value is valid' do
          schema = { oneOf: Array.new(1 + rand(3), test_schema) }
          expect { validator.validate(schema) }.not_to raise_error
        end

        it 'raises an exception if the oneOf value is not an array' do
          schema = { oneOf: 'not a array' }
          expect { validator.validate(schema) }.to raise_error(::Mongoff::Validator::Error)
        end

        it 'raises an exception if the oneOf value is an empty array' do
          schema = { oneOf: [] }
          expect { validator.validate(schema) }.to raise_error(::Mongoff::Validator::Error)
        end
      end

      context 'when validating keyword not' do

        it 'does not raise an exception if the not value is a valid schema' do
          schema = { not: test_schema }
          expect { validator.validate(schema) }.not_to raise_error
        end


        it 'raises an exception if the not value is not a JSON schema' do
          schema = { not: 'not valid schema' }
          expect { validator.validate(schema) }.to raise_error
        end
      end
    end

    context 'when validating Keywords for Applying Subschemas Conditionally' do

      it 'does not raise an exception if the if value a valid schema' do
        schema = { if: test_schema }
        expect { validator.validate(schema) }.not_to raise_error
      end

      it 'raises an exception if the if value is not a valid schema' do
        schema = { if: 'not valid schema' }
        expect { validator.validate(schema) }.to raise_error(::Mongoff::Validator::Error)
      end

      it 'does not raise an exception if the then value a valid schema' do
        schema = { then: test_schema }
        expect { validator.validate(schema) }.not_to raise_error
      end

      it 'raises an exception if the then value is not a valid schema' do
        schema = { then: 'not valid schema' }
        expect { validator.validate(schema) }.to raise_error(::Mongoff::Validator::Error)
      end

      it 'does not raise an exception if the else value a valid schema' do
        schema = { else: test_schema }
        expect { validator.validate(schema) }.not_to raise_error
      end

      it 'raises an exception if the else value is not a valid schema' do
        schema = { else: 'not valid schema' }
        expect { validator.validate(schema) }.to raise_error(::Mongoff::Validator::Error)
      end

      it 'does not raise an exception if the dependentSchema value is valid' do
        schema = {
          dependentSchema: {
            a: test_schema,
            b: test_schema
          }
        }
        expect { validator.validate(schema) }.not_to raise_error
      end

      it 'raises an exception if the dependentSchemas value is not an object' do
        schema = {
          dependentSchemas: 'not an object'
        }
        expect { validator.validate(schema) }.to raise_error(::Mongoff::Validator::Error)
      end

      it 'raises an exception if some dependentSchemas value is not a valid schema' do
        schema = {
          dependentSchemas: {
            a: test_schema,
            b: 'not valid schema'
          }
        }
        expect { validator.validate(schema) }.to raise_error(::Mongoff::Validator::Error)
      end
    end
  end

  context 'when validating an instance' do

    context 'when validating Boolean JSON Schemas' do

      it 'does not raise an exception if true schema values are present' do
        n = 1 + rand(5)
        instance = sample_instance
        n.downto(1) { |i| instance["allowed_#{i}"] = true }
        expect {
          validator.validate_instance(instance, data_type: data_type)
        }.not_to raise_error
      end

      it 'does not report errors if a Mongoff true schema value is present' do
        n = 1 + rand(5)
        obj = sample_instance
        n.downto(1) { |i| obj["allowed_#{i}"] = true }
        instance = data_type.new_from(obj)
        validator.soft_validates(instance)
        expect(instance.errors.empty?).to be true
      end

      it 'raises an exception if false schema value is present' do
        instance = sample_instance.merge(
          not_allowed: 'not allowed'
        )
        expect {
          validator.validate_instance(instance, data_type: data_type)
        }.to raise_error(::Mongoff::Validator::Error, "Value '#/not_allowed' is not allowed")
      end

      it 'reports errors if a Mongoff false schema value is present' do
        n = 2 + rand(5)
        obj = sample_instance
        n.downto(1) { |i| obj["not_allowed_#{i}"] = true }
        instance = data_type.new_from(obj)
        validator.soft_validates(instance)
        n.downto(1) do |i|
          expect(instance.errors["not_allowed_#{i}"]).to include('is not allowed')
        end
      end
    end

    context 'when validating Keywords for Any Instance Type' do

      context 'when validating keyword type' do

        it 'does not raise an exception if the instance is a mongoff record' do
          instance = data_type.new_from(
            null: nil,
            boolean: rand(2).to_b,
            obj: {},
            array: [],
            number: rand(10) + rand,
            string: 'string',
            integer: rand(10)
          )
          expect { validator.validate_instance(instance, data_type: data_type) }.not_to raise_error
        end

        it 'does not raise an exception if the instance and type are null' do
          instance = { null: nil }
          expect { validator.validate_instance(instance, data_type: data_type) }.not_to raise_error
        end

        it 'raises an error when the expected instance type is null' do
          instance = { null: 'not null' }
          expect {
            validator.validate_instance(instance, data_type: data_type)
          }.to raise_error(::Mongoff::Validator::Error, "Value '#/null' of type String is not an instance of type null")
        end

        it 'does not raise an exception if the instance and type are boolean' do
          instance = { boolean: rand(2).to_b }
          expect { validator.validate_instance(instance, data_type: data_type) }.not_to raise_error
        end

        it 'raises an error when the expected instance type is boolean' do
          instance = { boolean: 'not boolean' }
          expect {
            validator.validate_instance(instance, data_type: data_type)
          }.to raise_error(::Mongoff::Validator::Error, "Value '#/boolean' of type String is not an instance of type boolean")
        end

        it 'does not raise an exception if the instance and type are object' do
          instance = { obj: {} }
          expect { validator.validate_instance(instance, data_type: data_type) }.not_to raise_error
        end

        it 'raises an error when the expected instance type is object' do
          instance = { obj: 'not object' }
          expect {
            validator.validate_instance(instance, data_type: data_type)
          }.to raise_error(::Mongoff::Validator::Error, "Value '#/obj' of type String is not an instance of type object")
        end

        it 'does not raise an exception if the instance and type are array' do
          instance = { array: [] }
          expect { validator.validate_instance(instance, data_type: data_type) }.not_to raise_error
        end

        it 'raises an error when the expected instance type is array' do
          instance = { array: 'not array' }
          expect {
            validator.validate_instance(instance, data_type: data_type)
          }.to raise_error(::Mongoff::Validator::Error, "Value '#/array' of type String is not an instance of type array")
        end

        it 'does not raise an exception if the instance and type are number' do
          instance = { number: rand(10) + rand }
          expect { validator.validate_instance(instance, data_type: data_type) }.not_to raise_error
        end

        it 'raises an error when the expected instance type is number' do
          instance = { number: 'not number' }
          expect {
            validator.validate_instance(instance, data_type: data_type)
          }.to raise_error(::Mongoff::Validator::Error, "Value '#/number' of type String is not an instance of type number")
        end

        it 'does not raise an exception if the instance and type are integer' do
          instance = { integer: rand(10) }
          expect { validator.validate_instance(instance, data_type: data_type) }.not_to raise_error
        end

        it 'raises an error when the expected instance type is integer' do
          instance = { integer: 'not integer' }
          expect {
            validator.validate_instance(instance, data_type: data_type)
          }.to raise_error(::Mongoff::Validator::Error, "Value '#/integer' of type String is not an instance of type integer")
        end

        it 'does not raise an exception if the instance and type are string' do
          instance = { string: 'string' }
          expect { validator.validate_instance(instance, data_type: data_type) }.not_to raise_error
        end

        it 'raises an error when the expected instance type is string' do
          instance = { string: 123 }
          expect {
            validator.validate_instance(instance, data_type: data_type)
          }.to raise_error(::Mongoff::Validator::Error, "Value '#/string' of type Integer is not an instance of type string")
        end
      end

      context 'when validating keyword enum' do

        it 'does not raise an exception if a JSON enum instance is valid' do
          instance = { color: test_schema['properties']['color']['enum'].take(1)[0] }
          expect { validator.validate_instance(instance, data_type: data_type) }.not_to raise_error
        end

        it 'does not report errors if a Mongoff enum instance is valid' do
          instance = data_type.new_from(color: test_schema['properties']['color']['enum'].take(1)[0])
          validator.soft_validates(instance)
          expect(instance.errors.empty?).to be true
        end

        it 'raises an error when a JSON enum instance is not valid' do
          wrong_value = test_schema['properties']['color']['enum'].join
          instance = { color: wrong_value }
          expect {
            validator.validate_instance(instance, data_type: data_type)
          }.to raise_error(::Mongoff::Validator::Error, "Value '#/color' is not included in the enumeration")
        end

        it 'reports an error when a Mongoff enum instance is not valid' do
          wrong_value = test_schema['properties']['color']['enum'].join
          instance = data_type.new_from(color: wrong_value)
          validator.soft_validates(instance)
          expect(instance.errors[:color]).to include('is not included in the enumeration')
        end
      end

      context 'when validating keyword const' do

        it 'does not raise an exception if a JSON const instance is valid' do
          instance = { const: const_schema['const'] }
          expect { validator.validate_instance(instance, data_type: data_type) }.not_to raise_error
        end

        it 'does not report errors if a Mongoff const instance is valid' do
          instance = data_type.new_from(const: const_schema['const'])
          validator.soft_validates(instance)
          expect(instance.errors.empty?).to be true
        end

        it 'raises an error when a JSON const instance is not valid' do
          value = const_schema['const']
          wrong_value = "#{value}_wrong"
          instance = { const: wrong_value }
          expect {
            validator.validate_instance(instance, data_type: data_type)
          }.to raise_error(::Mongoff::Validator::Error, "Value '#/const' is not the const value '#{value}'")
        end

        it 'reports an error when a Mongoff const instance is not valid' do
          value = const_schema['const']
          wrong_value = "#{value}_wrong"
          instance = data_type.new_from(const: wrong_value)
          validator.soft_validates(instance)
          expect(instance.errors[:const]).to include("is not the const value '#{value}'")
        end
      end
    end

    context 'when validating Keywords for Numeric Instances' do

      context 'when validating keyword multipleOf' do

        it 'does not raise an exception if a JSON multipleOf instance is valid' do
          instance = { multipleOf: (1 + rand(10)) * test_schema['properties']['multipleOf']['multipleOf'] }
          expect { validator.validate_instance(instance, data_type: data_type) }.not_to raise_error
        end

        it 'does not report errors if a Mongoff multipleOf instance is valid' do
          instance = data_type.new_from(multipleOf: (1 + rand(10)) * test_schema['properties']['multipleOf']['multipleOf'])
          validator.soft_validates(instance)
          expect(instance.errors.empty?).to be true
        end

        it 'raises an error when a JSON multipleOf instance is not valid' do
          factor = test_schema['properties']['multipleOf']['multipleOf']
          wrong_value = (1 + rand(10)) * factor + rand
          instance = { multipleOf: wrong_value }
          expect {
            validator.validate_instance(instance, data_type: data_type)
          }.to raise_error(::Mongoff::Validator::Error, "Value '#/multipleOf' is not multiple of #{factor}")
        end

        it 'reports an error when a Mongoff multipleOf instance is not valid' do
          factor = test_schema['properties']['multipleOf']['multipleOf']
          wrong_value = (1 + rand(10)) * factor + rand
          instance = data_type.new_from(multipleOf: wrong_value)
          validator.soft_validates(instance)
          expect(instance.errors[:multipleOf]).to include("is not multiple of #{factor}")
        end
      end

      context 'when validating keyword maximum' do

        it 'does not raise an exception if a JSON maximum instance is valid' do
          instance = { maximum: maximum_schema['maximum'] - 1 - rand(1) }
          expect { validator.validate_instance(instance, data_type: data_type) }.not_to raise_error
        end

        it 'does not report errors if a Mongoff maximum instance is valid' do
          instance = data_type.new_from(maximum: maximum_schema['maximum'] - 1 - rand(1))
          validator.soft_validates(instance)
          expect(instance.errors.empty?).to be true
        end

        it 'does not raise an exception if a JSON maximum instance is maximum' do
          instance = { maximum: maximum_schema['maximum'] }
          expect { validator.validate_instance(instance, data_type: data_type) }.not_to raise_error
        end

        it 'does not report errors if a Mongoff maximum instance is maximum' do
          instance = data_type.new_from(maximum: maximum_schema['maximum'])
          validator.soft_validates(instance)
          expect(instance.errors.empty?).to be true
        end

        it 'raises an error when a JSON maximum instance is not valid' do
          maximum = maximum_schema['maximum']
          wrong_value = maximum + 1 + rand(10)
          instance = { maximum: wrong_value }
          expect {
            validator.validate_instance(instance, data_type: data_type)
          }.to raise_error(::Mongoff::Validator::Error, "Value '#/maximum' expected to be maximum #{maximum}")
        end

        it 'reports an error when a Mongoff maximum instance is not valid' do
          maximum = maximum_schema['maximum']
          wrong_value = maximum + 1 + rand(10)
          instance = data_type.new_from(maximum: wrong_value)
          validator.soft_validates(instance)
          expect(instance.errors[:maximum]).to include("expected to be maximum #{maximum}")
        end
      end

      context 'when validating keyword exclusiveMaximum' do

        it 'does not raise an exception if a JSON exclusiveMaximum instance is valid' do
          instance = { exclusiveMaximum: test_schema['properties']['exclusiveMaximum']['exclusiveMaximum'] - 1 - rand(10) }
          expect { validator.validate_instance(instance, data_type: data_type) }.not_to raise_error
        end

        it 'does not report errors if a Mongoff exclusiveMaximum instance is valid' do
          instance = data_type.new_from(exclusiveMaximum: test_schema['properties']['exclusiveMaximum']['exclusiveMaximum'] - 1 - rand(10))
          validator.soft_validates(instance)
          expect(instance.errors.empty?).to be true
        end

        it 'raises an error when a JSON exclusiveMaximum instance is not valid' do
          maximum = test_schema['properties']['exclusiveMaximum']['exclusiveMaximum']
          wrong_value = 1 + maximum
          instance = { exclusiveMaximum: wrong_value }
          expect {
            validator.validate_instance(instance, data_type: data_type)
          }.to raise_error(::Mongoff::Validator::Error, "Value '#/exclusiveMaximum' must be strictly less than #{maximum}")
        end

        it 'reports an error when a Mongoff exclusiveMaximum instance is not valid' do
          maximum = test_schema['properties']['exclusiveMaximum']['exclusiveMaximum']
          wrong_value = 1 + maximum
          instance = data_type.new_from(exclusiveMaximum: wrong_value)
          validator.soft_validates(instance)
          expect(instance.errors[:exclusiveMaximum]).to include("must be strictly less than #{maximum}")
        end

        it 'raises an error when a JSON exclusiveMaximum instance is maximum' do
          maximum = test_schema['properties']['exclusiveMaximum']['exclusiveMaximum']
          instance = { exclusiveMaximum: maximum }
          expect {
            validator.validate_instance(instance, data_type: data_type)
          }.to raise_error(::Mongoff::Validator::Error, "Value '#/exclusiveMaximum' must be strictly less than #{maximum}")
        end

        it 'reports an error when a Mongoff exclusiveMaximum instance is maximum' do
          maximum = test_schema['properties']['exclusiveMaximum']['exclusiveMaximum']
          instance = data_type.new_from(exclusiveMaximum: maximum)
          validator.soft_validates(instance)
          expect(instance.errors[:exclusiveMaximum]).to include("must be strictly less than #{maximum}")
        end
      end

      context 'when validating keyword minimum' do

        it 'does not raise an exception if a JSON minimum instance is valid' do
          instance = {
            minimum: minimum_schema['minimum'] + 1 + rand(1)
          }
          expect { validator.validate_instance(instance, data_type: data_type) }.not_to raise_error
        end

        it 'does not report errors if a Mongoff minimum instance is valid' do
          instance = data_type.new_from(
            minimum: minimum_schema['minimum'] + 1 + rand(1)
          )
          validator.soft_validates(instance)
          expect(instance.errors.empty?).to be true
        end

        it 'does not raise an exception if a JSON minimum instance is minimum' do
          instance = {
            minimum: minimum_schema['minimum']
          }
          expect { validator.validate_instance(instance, data_type: data_type) }.not_to raise_error
        end

        it 'does not report errors if a Mongoff minimum instance is minimum' do
          instance = data_type.new_from(
            minimum: minimum_schema['minimum']
          )
          validator.soft_validates(instance)
          expect(instance.errors.empty?).to be true
        end

        it 'raises an error when a JSON minimum instance is not valid' do
          minimum = minimum_schema['minimum']
          wrong_value = minimum - 1 - rand(10)
          instance = { minimum: wrong_value }
          expect {
            validator.validate_instance(instance, data_type: data_type)
          }.to raise_error(::Mongoff::Validator::Error, "Value '#/minimum' expected to be minimum #{minimum}")
        end

        it 'reports an error when a Mongoff minimum instance is not valid' do
          minimum = minimum_schema['minimum']
          wrong_value = minimum - 1 - rand(10)
          instance = data_type.new_from(minimum: wrong_value)
          validator.soft_validates(instance)
          expect(instance.errors[:minimum]).to include("expected to be minimum #{minimum}")
        end
      end

      context 'when validating keyword exclusiveMinimum' do

        it 'does not raise an exception if a JSON exclusiveMinimum instance is valid' do
          instance = { exclusiveMinimum: test_schema['properties']['exclusiveMinimum']['exclusiveMinimum'] + 1 + rand(10) }
          expect { validator.validate_instance(instance, data_type: data_type) }.not_to raise_error
        end

        it 'does not report errors if a Mongoff exclusiveMinimum instance is valid' do
          instance = data_type.new_from(exclusiveMinimum: test_schema['properties']['exclusiveMinimum']['exclusiveMinimum'] + 1 + rand(10))
          validator.soft_validates(instance)
          expect(instance.errors.empty?).to be true
        end

        it 'raises an error when a JSON exclusiveMinimum instance is not valid' do
          minimum = test_schema['properties']['exclusiveMinimum']['exclusiveMinimum']
          wrong_value = minimum - 1
          instance = { exclusiveMinimum: wrong_value }
          expect {
            validator.validate_instance(instance, data_type: data_type)
          }.to raise_error(::Mongoff::Validator::Error, "Value '#/exclusiveMinimum' must be strictly greater than #{minimum}")
        end

        it 'reports an error when a Mongoff exclusiveMinimum instance is not valid' do
          minimum = test_schema['properties']['exclusiveMinimum']['exclusiveMinimum']
          wrong_value = minimum - 1
          instance = data_type.new_from(exclusiveMinimum: wrong_value)
          validator.soft_validates(instance)
          expect(instance.errors[:exclusiveMinimum]).to include("must be strictly greater than #{minimum}")
        end

        it 'raises an error when a JSON exclusiveMinimum instance is minimum' do
          minimum = test_schema['properties']['exclusiveMinimum']['exclusiveMinimum']
          instance = { exclusiveMinimum: minimum }
          expect {
            validator.validate_instance(instance, data_type: data_type)
          }.to raise_error(::Mongoff::Validator::Error, "Value '#/exclusiveMinimum' must be strictly greater than #{minimum}")
        end

        it 'reports an error when a Mongoff exclusiveMinimum instance is minimum' do
          minimum = test_schema['properties']['exclusiveMinimum']['exclusiveMinimum']
          instance = data_type.new_from(exclusiveMinimum: minimum)
          validator.soft_validates(instance)
          expect(instance.errors[:exclusiveMinimum]).to include("must be strictly greater than #{minimum}")
        end
      end
    end

    context 'when validating Keywords for Strings' do

      context 'when validating keyword maxLength' do

        it 'does not raise an exception if a JSON maxLength instance is valid' do
          instance = {
            maxLength: 'a' * (test_schema['properties']['maxLength']['maxLength'] - 1 - rand(5))
          }
          expect { validator.validate_instance(instance, data_type: data_type) }.not_to raise_error
        end

        it 'does not report errors if a Mongoff maxLength instance is valid' do
          instance = data_type.new_from(
            maxLength: 'a' * (test_schema['properties']['maxLength']['maxLength'] - 1 - rand(5))
          )
          validator.soft_validates(instance)
          expect(instance.errors.empty?).to be true
        end

        it 'does not raise an exception if a JSON maxLength instance is maximum' do
          instance = {
            maxLength: 'a' * (test_schema['properties']['maxLength']['maxLength'])
          }
          expect { validator.validate_instance(instance, data_type: data_type) }.not_to raise_error
        end

        it 'does not report errors if a Mongoff maxLength instance is maximum' do
          instance = data_type.new_from(
            maxLength: 'a' * (test_schema['properties']['maxLength']['maxLength'])
          )
          validator.soft_validates(instance)
          expect(instance.errors.empty?).to be true
        end

        it 'raises an error when a JSON maxLength instance is not valid' do
          max_length = test_schema['properties']['maxLength']['maxLength']
          wrong_value = 'a' * (max_length + 1 + rand(5))
          instance = { maxLength: wrong_value }
          expect {
            validator.validate_instance(instance, data_type: data_type)
          }.to raise_error(::Mongoff::Validator::Error, "Value '#/maxLength' is too long (#{wrong_value.length} of #{max_length} max)")
        end

        it 'reports an error when a Mongoff maxLength instance is not valid' do
          max_length = test_schema['properties']['maxLength']['maxLength']
          wrong_value = 'a' * (max_length + 1 + rand(5))
          instance = data_type.new_from(maxLength: wrong_value)
          validator.soft_validates(instance)
          expect(instance.errors[:maxLength]).to include("is too long (#{wrong_value.length} of #{max_length} max)")
        end
      end

      context 'when validating keyword minLength' do

        it 'does not raise an exception if a JSON minLength instance is valid' do
          instance = {
            minLength: 'a' * (test_schema['properties']['minLength']['minLength'] + 1 + rand(5))
          }
          expect { validator.validate_instance(instance, data_type: data_type) }.not_to raise_error
        end

        it 'does not report errors if a Mongoff minLength instance is valid' do
          instance = data_type.new_from(
            minLength: 'a' * (test_schema['properties']['minLength']['minLength'] + 1 + rand(5))
          )
          validator.soft_validates(instance)
          expect(instance.errors.empty?).to be true
        end

        it 'does not raise an exception if a JSON minLength instance is minimum' do
          instance = {
            minLength: 'a' * (test_schema['properties']['minLength']['minLength'])
          }
          expect { validator.validate_instance(instance, data_type: data_type) }.not_to raise_error
        end

        it 'does not report errors if a Mongoff maxLength instance is minimum' do
          instance = data_type.new_from(
            minLength: 'a' * (test_schema['properties']['minLength']['minLength'])
          )
          validator.soft_validates(instance)
          expect(instance.errors.empty?).to be true
        end

        it 'raises an error when a JSON minLength instance is not valid' do
          min_length = test_schema['properties']['minLength']['minLength']
          wrong_value = 'a' * (min_length - 1 - rand(5))
          instance = { minLength: wrong_value }
          expect {
            validator.validate_instance(instance, data_type: data_type)
          }.to raise_error(::Mongoff::Validator::Error, "Value '#/minLength' is too short (#{wrong_value.length} of #{min_length} min)")
        end

        it 'reports an error when a Mongoff minLength instance is not valid' do
          min_length = test_schema['properties']['minLength']['minLength']
          wrong_value = 'a' * (min_length - 1 - rand(5))
          instance = data_type.new_from(minLength: wrong_value)
          validator.soft_validates(instance)
          expect(instance.errors[:minLength]).to include("is too short (#{wrong_value.length} of #{min_length} min)")
        end
      end

      context 'when validating keyword pattern' do

        it 'does not raise an exception if a JSON pattern instance is valid' do
          instance = { pattern: 'support@cenit.io' }
          expect { validator.validate_instance(instance, data_type: data_type) }.not_to raise_error
        end

        it 'does not report errors if a Mongoff pattern instance is valid' do
          instance = data_type.new_from(pattern: 'support@cenit.io')
          validator.soft_validates(instance)
          expect(instance.errors.empty?).to be true
        end

        it 'raises an error when a JSON pattern instance is not valid' do
          pattern = test_schema['properties']['pattern']['pattern']
          wrong_value = 'not valid'
          instance = { pattern: wrong_value }
          expect {
            validator.validate_instance(instance, data_type: data_type)
          }.to raise_error(::Mongoff::Validator::Error, "Value '#/pattern' does not match the pattern #{pattern}")
        end

        it 'reports an error when a Mongoff pattern instance is not valid' do
          pattern = test_schema['properties']['pattern']['pattern']
          wrong_value = 'not valid'
          instance = data_type.new_from(pattern: wrong_value)
          validator.soft_validates(instance)
          expect(instance.errors[:pattern]).to include("does not match the pattern #{pattern}")
        end
      end

      context 'when validating defined formats' do

        context 'when validating Dates and Times' do

          it 'does not raise an exception if a date format value is valid' do
            instance = { date: Time.now.to_s.split(' ').first }
            expect { validator.validate_instance(instance, data_type: data_type) }.not_to raise_error
          end

          it 'does not raise an exception if a date format value is a date instance' do
            instance = { date: Time.now.to_s.to_date }
            expect { validator.validate_instance(instance, data_type: data_type) }.not_to raise_error
          end

          it 'does not report errors if a Mongoff date format value is valid' do
            instance = data_type.new_from(date: Time.now.to_s.to_date)
            validator.soft_validates(instance)
            expect(instance.errors.empty?).to be true
          end

          it 'raises an exception if the date format value is not valid' do
            wrong_value = 'not a date'
            instance = { date: wrong_value }
            expect {
              validator.validate_instance(instance, data_type: data_type)
            }.to raise_error(::Mongoff::Validator::Error, "Value '#/date' does not complies format date: invalid date")
          end

          it 'does not raise an exception if a time format value is valid' do
            instance = { time: Time.now.to_s.split(' ')[1..2].join(' ') }
            expect { validator.validate_instance(instance, data_type: data_type) }.not_to raise_error
          end

          it 'does not raise an exception if a time format value is a time instance' do
            instance = { time: Time.now.to_s.to_time }
            expect { validator.validate_instance(instance, data_type: data_type) }.not_to raise_error
          end

          it 'does not report errors if a Mongoff time format value is valid' do
            instance = data_type.new_from(time: Time.now.to_s.to_time)
            validator.soft_validates(instance)
            expect(instance.errors.empty?).to be true
          end

          it 'raises an exception if the time format value is not valid' do
            wrong_value = 'not a time'
            instance = { time: wrong_value }
            expect {
              validator.validate_instance(instance, data_type: data_type)
            }.to raise_error(::Mongoff::Validator::Error, "Value '#/time' does not complies format time: invalid date")
          end

          it 'does not raise an exception if a date-time format value is valid' do
            instance = { date_time: Time.now.to_s.to_datetime.to_s }
            expect { validator.validate_instance(instance, data_type: data_type) }.not_to raise_error
          end

          it 'does not raise an exception if a date-time format value is a time instance' do
            instance = { date_time: Time.now.to_s.to_datetime }
            expect { validator.validate_instance(instance, data_type: data_type) }.not_to raise_error
          end

          it 'does not report errors if a Mongoff date-time format value is valid' do
            instance = data_type.new_from(date_time: Time.now.to_s.to_time)
            validator.soft_validates(instance)
            expect(instance.errors.empty?).to be true
          end

          it 'raises an exception if the date-time format value is not valid' do
            wrong_value = 'not a date-time'
            instance = { date_time: wrong_value }
            expect {
              validator.validate_instance(instance, data_type: data_type)
            }.to raise_error(::Mongoff::Validator::Error, "Value '#/date_time' does not complies format date-time: invalid date")
          end
        end

        context 'when validating an Email Address' do

          it 'does not raise an exception if an email format value is valid' do
            instance = { email: 'support@cenit.io' }
            expect { validator.validate_instance(instance, data_type: data_type) }.not_to raise_error
          end

          it 'does not report errors if a Mongoff email format value is valid' do
            instance = data_type.new_from(email: 'support@cenit.io')
            validator.soft_validates(instance)
            expect(instance.errors.empty?).to be true
          end

          it 'raises an exception if the email format value is not valid' do
            wrong_value = 'not an email'
            instance = { email: wrong_value }
            expect {
              validator.validate_instance(instance, data_type: data_type)
            }.to raise_error(::Mongoff::Validator::Error, "Value '#/email' is not a valid email address")
          end

          it 'reports an error when a Mongoff email format value is not valid' do
            wrong_value = 'not an email'
            instance = data_type.new_from(email: wrong_value)
            validator.soft_validates(instance)
            expect(instance.errors[:email]).to include('is not a valid email address')
          end
        end

        context 'when validating an IPv4 address' do

          it 'does not raise an exception if an IPv4 format value is valid' do
            instance = { ipv4: [rand(256), rand(256), rand(256), rand(256)].join('.') }
            expect { validator.validate_instance(instance, data_type: data_type) }.not_to raise_error
          end

          it 'does not report errors if a Mongoff IPv4 format value is valid' do
            instance = data_type.new_from(ipv4: [rand(256), rand(256), rand(256), rand(256)].join('.'))
            validator.soft_validates(instance)
            expect(instance.errors.empty?).to be true
          end

          it 'raises an exception if the ipv4 format value is not valid' do
            wrong_value = 'not an ipv4'
            instance = { ipv4: wrong_value }
            expect {
              validator.validate_instance(instance, data_type: data_type)
            }.to raise_error(::Mongoff::Validator::Error, "Value '#/ipv4' is not a valid IPv4")
          end

          it 'reports an error when a Mongoff ipv4 format value is not valid' do
            wrong_value = 'not an ipv4'
            instance = data_type.new_from(ipv4: wrong_value)
            validator.soft_validates(instance)
            expect(instance.errors[:ipv4]).to include('is not a valid IPv4')
          end
        end

        context 'when validating an IPv6 address' do

          it 'does not raise an exception if an IPv6 format value is valid' do
            instance = { ipv6: '2001:0db8:85a3:0000:0000:8a2e:0370:7334' }
            expect { validator.validate_instance(instance, data_type: data_type) }.not_to raise_error
          end

          it 'does not report errors if a Mongoff IPv6 format value is valid' do
            instance = data_type.new_from(ipv6: '2001:0db8:85a3:0000:0000:8a2e:0370:7334')
            validator.soft_validates(instance)
            expect(instance.errors.empty?).to be true
          end

          it 'raises an exception if the ipv6 format value is not valid' do
            wrong_value = 'not an ipv6'
            instance = { ipv6: wrong_value }
            expect {
              validator.validate_instance(instance, data_type: data_type)
            }.to raise_error(::Mongoff::Validator::Error, "Value '#/ipv6' is not a valid IPv6")
          end

          it 'reports an error when a Mongoff ipv6 format value is not valid' do
            wrong_value = 'not an ipv6'
            instance = data_type.new_from(ipv6: wrong_value)
            validator.soft_validates(instance)
            expect(instance.errors[:ipv6]).to include('is not a valid IPv6')
          end
        end

        context 'when validating a Host Name' do

          it 'does not raise an exception if a Hostname format value is valid' do
            instance = { hostname: 'cenit.io' }
            expect { validator.validate_instance(instance, data_type: data_type) }.not_to raise_error
          end

          it 'does not report errors if a Mongoff Hostname format value is valid' do
            instance = data_type.new_from(hostname: 'cenit.io')
            validator.soft_validates(instance)
            expect(instance.errors.empty?).to be true
          end

          it 'raises an exception if the hostname format value is not valid' do
            wrong_value = 'not a host name'
            instance = { hostname: wrong_value }
            expect {
              validator.validate_instance(instance, data_type: data_type)
            }.to raise_error(::Mongoff::Validator::Error, "Value '#/hostname' is not a valid host name")
          end

          it 'reports an error when a Mongoff hostname format value is not valid' do
            wrong_value = 'not a hostname'
            instance = data_type.new_from(hostname: wrong_value)
            validator.soft_validates(instance)
            expect(instance.errors[:hostname]).to include('is not a valid host name')
          end
        end

        context 'when validating an URI' do

          it 'does not raise an exception if an URI format value is valid' do
            instance = { uri: 'https://cenit.io' }
            expect { validator.validate_instance(instance, data_type: data_type) }.not_to raise_error
          end

          it 'does not report errors if a Mongoff URI format value is valid' do
            instance = data_type.new_from(uri: 'https://cenit.io')
            validator.soft_validates(instance)
            expect(instance.errors.empty?).to be true
          end

          it 'raises an exception if the uri format value is not valid' do
            wrong_value = 'not an uri'
            instance = { uri: wrong_value }
            expect {
              validator.validate_instance(instance, data_type: data_type)
            }.to raise_error(::Mongoff::Validator::Error, "Value '#/uri' is not a valid URI")
          end

          it 'reports an error when a Mongoff uri format value is not valid' do
            wrong_value = 'not an uri'
            instance = data_type.new_from(uri: wrong_value)
            validator.soft_validates(instance)
            expect(instance.errors[:uri]).to include('is not a valid URI')
          end
        end

        context 'when validating an UUID' do

          it 'does not raise an exception if an UUID format value is valid' do
            instance = { uuid: '123e4567-e89b-12d3-a456-426655440000' }
            expect { validator.validate_instance(instance, data_type: data_type) }.not_to raise_error
          end

          it 'does not report errors if a Mongoff UUID format value is valid' do
            instance = data_type.new_from(uuid: '123e4567-e89b-12d3-a456-426655440000')
            validator.soft_validates(instance)
            expect(instance.errors.empty?).to be true
          end

          it 'raises an exception if the uuid format value is not valid' do
            wrong_value = 'not an uuid'
            instance = { uuid: wrong_value }
            expect {
              validator.validate_instance(instance, data_type: data_type)
            }.to raise_error(::Mongoff::Validator::Error, "Value '#/uuid' is not a valid UUID")
          end

          it 'reports an error when a Mongoff uuid format value is not valid' do
            wrong_value = 'not an uuid'
            instance = data_type.new_from(uuid: wrong_value)
            validator.soft_validates(instance)
            expect(instance.errors[:uuid]).to include('is not a valid UUID')
          end
        end
      end
    end

    context 'when validating keywords for Applying Subschemas to Arrays' do

      context 'when validating keyword items' do

        context 'when items schema is simple and embedded' do

          it 'does not raise an exception if an items embedded value is valid' do
            instance = { embedded_array: [
              { integer: rand(100) },
              { number: rand(100) + rand }
            ] }
            expect { validator.validate_instance(instance, data_type: data_type) }.not_to raise_error
          end

          it 'does not report errors if a Mongoff items embedded value is valid' do
            instance = data_type.new_from(embedded_array: [
              { integer: rand(100) },
              { number: rand(100) + rand }
            ])
            validator.soft_validates(instance)
            expect(instance.errors.empty?).to be true
          end

          it 'raises an exception if an items embedded value is not an array' do
            wrong_value = 'not an array'
            instance = { embedded_array: wrong_value }
            expect {
              validator.validate_instance(instance, data_type: data_type)
            }.to raise_error(::Mongoff::Validator::Error, "Value '#/embedded_array' of type String is not an instance of type array")
          end

          it 'reports errors if a Mongoff items embedded value is not an array' do
            wrong_value = 'not an array'
            expect {
              data_type.new_from_json(embedded_array: wrong_value)
            }.to raise_error(Exception, "Can not assign '#{wrong_value}' as simple content to A")
          end

          it 'raises an exception if an items embedded value is not a valid array' do
            wrong_value = 'not a number'
            instance = { embedded_array: [
              { number: wrong_value }
            ] }
            expect {
              validator.validate_instance(instance, data_type: data_type)
            }.to raise_error(::Mongoff::Validator::Error, "Value '#/embedded_array[0]/number' of type String is not an instance of type number")
          end

          it 'reports errors if a Mongoff items embedded value is not a valid array' do
            const = const_schema['const']
            wrong_const = "not #{const}"
            maximum = maximum_schema['maximum']
            wrong_maximum = maximum + 1
            instance = data_type.new_from_json(embedded_array: [
              { const: wrong_const },
              { maximum: wrong_maximum }
            ])
            validator.soft_validates(instance)
            expect(instance.errors[:base]).to include('property embedded_array has errors')
            expect(instance.embedded_array[0].errors[:const]).to include("is not the const value '#{const}'")
            expect(instance.embedded_array[1].errors[:maximum]).to include("expected to be maximum #{maximum}")
          end
        end

        context 'when items schema is simple and referenced' do

          it 'does not raise an exception if an items referenced value is valid' do
            instance = { array_ref: [
              { integer: rand(100) },
              { number: rand(100) + rand }
            ] }
            expect { validator.validate_instance(instance, data_type: data_type) }.not_to raise_error
          end

          it 'does not report errors if a Mongoff items referenced value is valid' do
            instance = data_type.new_from(array_ref: [
              { integer: rand(100) },
              { number: rand(100) + rand }
            ])
            validator.soft_validates(instance)
            expect(instance.errors.empty?).to be true
          end

          it 'raises an exception if an items referenced value is not an array' do
            wrong_value = 'not an array'
            instance = { array_ref: wrong_value }
            expect {
              validator.validate_instance(instance, data_type: data_type)
            }.to raise_error(::Mongoff::Validator::Error, "Value '#/array_ref' of type String is not an instance of type array")
          end

          it 'reports errors if a Mongoff items referenced value is not an array' do
            wrong_value = 'not an array'
            expect {
              data_type.new_from_json(array_ref: wrong_value)
            }.to raise_error(Exception, "Can not assign '#{wrong_value}' as simple content to A")
          end

          it 'raises an exception if an items referenced value is not a valid array' do
            wrong_value = 'not a number'
            instance = { array_ref: [
              { number: wrong_value }
            ] }
            expect {
              validator.validate_instance(instance, data_type: data_type)
            }.to raise_error(::Mongoff::Validator::Error, "Value '#/array_ref[0]/number' of type String is not an instance of type number")
          end

          it 'reports errors if a Mongoff items referenced value is not a valid array' do
            const = const_schema['const']
            wrong_const = "not #{const}"
            maximum = maximum_schema['maximum']
            wrong_maximum = maximum + 1
            instance = data_type.new_from_json(array_ref: [
              { const: wrong_const },
              { maximum: wrong_maximum }
            ])
            validator.soft_validates(instance)
            expect(instance.errors[:base]).to include('property array_ref has errors')
            expect(instance.array_ref[0].errors[:const]).to include("is not the const value '#{const}'")
            expect(instance.array_ref[1].errors[:maximum]).to include("expected to be maximum #{maximum}")
          end
        end

        context 'when items schema is an array' do

          it 'does not raise an exception if an items embedded value is valid' do
            instance = { embedded_array_items: [
              const_schema['const'],
              { maximum: maximum_schema['maximum'] }
            ] }
            expect { validator.validate_instance(instance, data_type: data_type) }.not_to raise_error
          end

          it 'does not raise an exception if the embedded items is greater than then the schemas array' do
            instance = { embedded_array_items: [
              const_schema['const'],
              { maximum: maximum_schema['maximum'] },
              { minimum: minimum_schema['minimum'] }
            ] }
            expect { validator.validate_instance(instance, data_type: data_type) }.not_to raise_error
          end

          it 'does not raise an exception if the embedded items count is shorter than then the schemas array' do
            instance = { embedded_array_items: [
              const_schema['const']
            ] }
            expect { validator.validate_instance(instance, data_type: data_type) }.not_to raise_error
          end

          it 'does not report errors if a Mongoff items embedded value is valid' do
            instance = data_type.new_from(embedded_array_items: [
              const_schema['const'],
              { maximum: maximum_schema['maximum'] }
            ])
            validator.soft_validates(instance)
            expect(instance.errors.empty?).to be true
          end

          it 'does not raise an exception if the embedded items count is greater than then the schemas array' do
            instance = data_type.new_from_json(embedded_array_items: [
              const_schema['const'],
              { maximum: maximum_schema['maximum'] },
              { minimum: minimum_schema['minimum'] }
            ])
            validator.soft_validates(instance)
            expect(instance.errors.empty?).to be true
          end

          it 'does not raise an exception if the embedded items count is shorter than then the schemas array' do
            instance = data_type.new_from_json(embedded_array_items: [
              const_schema['const']
            ])
            validator.soft_validates(instance)
            expect(instance.errors.empty?).to be true
          end

          it 'raises an exception if an items embedded value is not an array' do
            wrong_value = 'not an array'
            instance = { embedded_array_items: wrong_value }
            expect {
              validator.validate_instance(instance, data_type: data_type)
            }.to raise_error(::Mongoff::Validator::Error, "Value '#/embedded_array_items' of type String is not an instance of type array")
          end

          it 'reports errors if a Mongoff items embedded value is not an array' do
            wrong_value = 'not an array'
            instance = data_type.new_from_json(embedded_array_items: wrong_value)
            validator.soft_validates(instance)
            expect(instance.errors[:embedded_array_items]).to include("Item #/embedded_array_items[0] is not the const value '#{const_schema['const']}'")
          end

          it 'raises an exception if an items embedded value is not a valid array' do
            const = const_schema['const']
            wrong_const = "not #{const}"
            instance = { embedded_array_items: [
              wrong_const
            ] }
            expect {
              validator.validate_instance(instance, data_type: data_type)
            }.to raise_error(::Mongoff::Validator::Error, "Item #/embedded_array_items[0] is not the const value '#{const}'")
          end

          it 'reports errors if a Mongoff items embedded value is not a valid array' do
            maximum = maximum_schema['maximum']
            wrong_maximum = maximum + 1
            instance = data_type.new_from_json(embedded_array_items: [
              const_schema['const'],
              { maximum: wrong_maximum }
            ])
            validator.soft_validates(instance)
            expect(instance.errors[:embedded_array_items]).to include("Value '#/embedded_array_items[1]/maximum' expected to be maximum #{maximum}")
          end
        end
      end

      context 'when validating keyword additionalItems' do

        it 'does not raise an exception if an items embedded value is valid' do
          instance = { embedded_additionalItems: [
            const_schema['const'],
            { number: rand(100) + rand },
            maximum_schema['maximum'] - rand(2),
            maximum_schema['maximum'] - rand(2)
          ] }
          expect { validator.validate_instance(instance, data_type: data_type) }.not_to raise_error
        end

        it 'does not report errors if a Mongoff items embedded value is valid' do
          instance = data_type.new_from(embedded_additionalItems: [
            const_schema['const'],
            { number: rand(100) + rand },
            maximum_schema['maximum'] - rand(2),
            maximum_schema['maximum'] - rand(2)
          ])
          validator.soft_validates(instance)
          expect(instance.errors.empty?).to be true
        end

        it 'raises an exception if an items embedded value is not a valid array' do
          instance = { embedded_additionalItems: [
            const_schema['const'],
            { number: rand(100) + rand },
            maximum_schema['maximum'] - rand(2),
            maximum_schema['maximum'] + 1 + rand(100)
          ] }
          expect {
            validator.validate_instance(instance, data_type: data_type)
          }.to raise_error(::Mongoff::Validator::Error, "Item #/embedded_additionalItems[3] expected to be maximum #{maximum_schema['maximum']}")
        end

        it 'reports errors if a Mongoff items embedded value is not a valid array' do
          instance = data_type.new_from_json(embedded_additionalItems: [
            const_schema['const'],
            { number: rand(100) + rand },
            maximum_schema['maximum'] - rand(2),
            maximum_schema['maximum'] + 1 + rand(100)
          ])
          validator.soft_validates(instance)
          expect(instance.errors[:embedded_additionalItems]).to include("Item #/embedded_additionalItems[3] expected to be maximum #{maximum_schema['maximum']}")
        end
      end

      context 'when validating keyword maxItems' do

        context 'when items schema is embedded' do

          it 'does not raise an exception if a maxItems instance size is not maximum' do
            size = max_items_schema['maxItems'] - 1 - rand(5)
            instance = {
              embedded_maxItems: Array(1..size)
            }
            expect { validator.validate_instance(instance, data_type: data_type) }.not_to raise_error
          end

          it 'does not raise an exception if a Mongoff maxItems instance size is not maximum' do
            size = max_items_schema['maxItems'] - 1 - rand(5)
            instance = data_type.new_from(
              embedded_maxItems: Array(1..size)
            )
            expect { validator.validate_instance(instance, data_type: data_type) }.not_to raise_error
          end

          it 'does not raise an exception if a maxItems instance size is maximum' do
            size = max_items_schema['maxItems']
            instance = {
              embedded_maxItems: Array(1..size)
            }
            expect { validator.validate_instance(instance, data_type: data_type) }.not_to raise_error
          end

          it 'does not raise an exception if a Mongoff maxItems instance size is maximum' do
            size = max_items_schema['maxItems']
            instance = data_type.new_from(
              embedded_maxItems: Array(1..size)
            )
            expect { validator.validate_instance(instance, data_type: data_type) }.not_to raise_error
          end

          it 'raises an exception if a maxItems instance overflows' do
            wrong_size = max_items_schema['maxItems'] + 1 + rand(10)
            instance = {
              embedded_maxItems: Array(1..wrong_size)
            }
            expect {
              validator.validate_instance(instance, data_type: data_type)
            }.to raise_error(::Mongoff::Validator::Error, "Value '#/embedded_maxItems' has too many items (#{wrong_size} of #{max_items_schema['maxItems']} max)")
          end

          it 'raises an exception if a Mongoff maxItems instance overflows' do
            wrong_size = max_items_schema['maxItems'] + 1 + rand(10)
            instance = data_type.new_from_json(
              embedded_maxItems: Array(1..wrong_size)
            )
            validator.soft_validates(instance)
            expect(instance.errors[:embedded_maxItems]).to include("has too many items (#{wrong_size} of #{max_items_schema['maxItems']} max)")
          end
        end

        context 'when items schema is referenced' do

          it 'does not raise an exception if a maxItems instance size is not maximum' do
            size = max_items_schema['maxItems'] - 1 - rand(5)
            instance = {
              ref_maxItems: Array(1..size).map { |i| { integer: i } }
            }
            expect { validator.validate_instance(instance, data_type: data_type) }.not_to raise_error
          end

          it 'does not raise an exception if a Mongoff maxItems instance size is not maximum' do
            size = max_items_schema['maxItems'] - 1 - rand(5)
            instance = data_type.new_from(
              ref_maxItems: Array(1..size).map { |i| { integer: i } }
            )
            expect { validator.validate_instance(instance, data_type: data_type) }.not_to raise_error
          end

          it 'does not raise an exception if a maxItems instance size is maximum' do
            size = max_items_schema['maxItems']
            instance = {
              ref_maxItems: Array(1..size).map { |i| { integer: i } }
            }
            expect { validator.validate_instance(instance, data_type: data_type) }.not_to raise_error
          end

          it 'does not raise an exception if a Mongoff maxItems instance size is maximum' do
            size = max_items_schema['maxItems']
            instance = data_type.new_from(
              ref_maxItems: Array(1..size).map { |i| { integer: i } }
            )
            expect { validator.validate_instance(instance, data_type: data_type) }.not_to raise_error
          end

          it 'raises an exception if a maxItems instance overflows' do
            wrong_size = max_items_schema['maxItems'] + 1 + rand(10)
            instance = {
              ref_maxItems: Array(1..wrong_size).map { |i| { integer: i } }
            }
            expect {
              validator.validate_instance(instance, data_type: data_type)
            }.to raise_error(::Mongoff::Validator::Error, "Value '#/ref_maxItems' has too many items (#{wrong_size} of #{max_items_schema['maxItems']} max)")
          end

          it 'raises an exception if a Mongoff maxItems instance overflows' do
            wrong_size = max_items_schema['maxItems'] + 1 + rand(10)
            instance = data_type.new_from_json(
              ref_maxItems: Array(1..wrong_size).map { |i| { integer: i } }
            )
            validator.soft_validates(instance)
            expect(instance.errors[:ref_maxItems]).to include("has too many items (#{wrong_size} of #{max_items_schema['maxItems']} max)")
          end
        end
      end

      context 'when validating keyword minItems' do

        context 'when items schema is embedded' do

          it 'does not raise an exception if a minItems instance size is not minimum' do
            size = min_items_schema['minItems'] + 1 + rand(5)
            instance = {
              embedded_minItems: Array(1..size)
            }
            expect { validator.validate_instance(instance, data_type: data_type) }.not_to raise_error
          end

          it 'does not raise an exception if a Mongoff minItems instance size is not minimum' do
            size = min_items_schema['minItems'] + 1 + rand(5)
            instance = data_type.new_from(
              { embedded_minItems: Array(1..size) }
            )
            expect { validator.validate_instance(instance, data_type: data_type) }.not_to raise_error
          end

          it 'does not raise an exception if a minItems instance size is minimum' do
            size = min_items_schema['minItems']
            instance = {
              embedded_minItems: Array(1..size)
            }
            expect { validator.validate_instance(instance, data_type: data_type) }.not_to raise_error
          end

          it 'does not raise an exception if a Mongoff minItems instance size is minimum' do
            size = min_items_schema['minItems']
            instance = data_type.new_from(
              embedded_minItems: Array(1..size)
            )
            expect { validator.validate_instance(instance, data_type: data_type) }.not_to raise_error
          end

          it 'raises an exception if a minItems instance underflows' do
            wrong_size = min_items_schema['minItems'] - 1 - rand(5)
            instance = {
              embedded_minItems: Array(1..wrong_size)
            }
            expect {
              validator.validate_instance(instance, data_type: data_type)
            }.to raise_error(::Mongoff::Validator::Error, "Value '#/embedded_minItems' has too few items (#{wrong_size} for #{min_items_schema['minItems']} min)")
          end

          it 'raises an exception if a Mongoff minItems instance underflows' do
            wrong_size = min_items_schema['minItems'] - 1 - rand(5)
            instance = data_type.new_from_json(
              embedded_minItems: Array(1..wrong_size)
            )
            validator.soft_validates(instance)
            expect(instance.errors[:embedded_minItems]).to include("has too few items (#{wrong_size} for #{min_items_schema['minItems']} min)")
          end
        end

        context 'when items schema is referenced' do

          it 'does not raise an exception if a minItems instance size is not minimum' do
            size = min_items_schema['minItems'] + 1 + rand(5)
            instance = {
              ref_minItems: Array(1..size).map { |i| { integer: i } }
            }
            expect { validator.validate_instance(instance, data_type: data_type) }.not_to raise_error
          end

          it 'does not raise an exception if a Mongoff minItems instance size is not minimum' do
            size = min_items_schema['minItems'] + 1 + rand(5)
            instance = data_type.new_from(
              ref_minItems: Array(1..size).map { |i| { integer: i } }
            )
            expect { validator.validate_instance(instance, data_type: data_type) }.not_to raise_error
          end

          it 'does not raise an exception if a minItems instance size is minimum' do
            size = min_items_schema['minItems']
            instance = {
              ref_minItems: Array(1..size).map { |i| { integer: i } }
            }
            expect { validator.validate_instance(instance, data_type: data_type) }.not_to raise_error
          end

          it 'does not raise an exception if a Mongoff minItems instance size is minimum' do
            size = min_items_schema['minItems']
            instance = data_type.new_from(
              ref_minItems: Array(1..size).map { |i| { integer: i } }
            )
            expect { validator.validate_instance(instance, data_type: data_type) }.not_to raise_error
          end

          it 'raises an exception if a minItems instance underflows' do
            wrong_size = min_items_schema['minItems'] - 1 - rand(3)
            instance = {
              ref_minItems: Array(1..wrong_size).map { |i| { integer: i } }
            }
            expect {
              validator.validate_instance(instance, data_type: data_type)
            }.to raise_error(::Mongoff::Validator::Error, "Value '#/ref_minItems' has too few items (#{wrong_size} for #{min_items_schema['minItems']} min)")
          end

          it 'raises an exception if a Mongoff minItems instance underflows' do
            wrong_size = min_items_schema['minItems'] - 1 - rand(3)
            instance = data_type.new_from_json(
              ref_minItems: Array(1..wrong_size).map { |i| { integer: i } }
            )
            validator.soft_validates(instance)
            expect(instance.errors[:ref_minItems]).to include("has too few items (#{wrong_size} for #{min_items_schema['minItems']} min)")
          end
        end
      end

      context 'when validating keyword uniqueItems' do

        it 'does not raise an exception if an uniqueItems embedded value is valid' do
          instance = { embedded_uniqueItems: [1, '2', 'three', false] }
          expect { validator.validate_instance(instance, data_type: data_type) }.not_to raise_error
        end

        it 'does not raise an exception if a not uniqueItems embedded value is valid' do
          instance = { embedded_not_uniqueItems: [1, '2', 'three', 1] }
          expect { validator.validate_instance(instance, data_type: data_type) }.not_to raise_error
        end

        it 'does not report errors if a Mongoff uniqueItems embedded value is valid' do
          instance = data_type.new_from(
            embedded_uniqueItems: [1, '2', 'three', false]
          )
          validator.soft_validates(instance)
          expect(instance.errors.empty?).to be true
        end

        it 'does not report errors if a Mongoff not uniqueItems embedded value is valid' do
          instance = data_type.new_from(
            embedded_not_uniqueItems: [1, '2', 'three', 1]
          )
          validator.soft_validates(instance)
          expect(instance.errors.empty?).to be true
        end

        it 'raises an exception if an uniqueItems embedded value is not valid' do
          instance = { embedded_uniqueItems: [1, '2', 'three', 1] }
          expect {
            validator.validate_instance(instance, data_type: data_type)
          }.to raise_error(::Mongoff::Validator::Error, "Value '#/embedded_uniqueItems' contains repeated items")
        end

        it 'reports errors if a Mongoff uniqueItems embedded value is not valid' do
          instance = data_type.new_from(
            embedded_uniqueItems: [1, '2', 'three', 1]
          )
          validator.soft_validates(instance)
          expect(instance.errors[:embedded_uniqueItems]).to include("contains repeated items")
        end
      end

      context 'when validating keyword contains' do

        context 'when items schema is embedded' do

          it 'does not raise an exception if a contains embedded value is valid' do
            const = const_schema['const']
            items = Array(1..(5 + rand(10))).map { |i| "not #{const} #{i}" }
            items[rand(items.length - 1)] = const
            instance = { embedded_contains: items }
            expect { validator.validate_instance(instance, data_type: data_type) }.not_to raise_error
          end

          it 'does not report errors if a Mongoff contains embedded value is valid' do
            const = const_schema['const']
            items = Array(1..(5 + rand(10))).map { |i| "not #{const} #{i}" }
            items[rand(items.length - 1)] = const
            instance = data_type.new_from(
              embedded_contains: items
            )
            validator.soft_validates(instance)
            expect(instance.errors.empty?).to be true
          end

          it 'raises an exception if a contains embedded value is not valid' do
            const = const_schema['const']
            instance = {
              embedded_contains: Array(1..(5 + rand(10))).map { |i| "not #{const} #{i}" }
            }
            expect {
              validator.validate_instance(instance, data_type: data_type)
            }.to raise_error(::Mongoff::Validator::Error, "Value '#/embedded_contains' have no items matching the contains schema")
          end

          it 'reports errors if a Mongoff contains embedded value is not valid' do
            const = const_schema['const']
            instance = data_type.new_from(
              embedded_contains: Array(1..(5 + rand(10))).map { |i| "not #{const} #{i}" }
            )
            validator.soft_validates(instance)
            expect(instance.errors[:embedded_contains]).to include('have no items matching the contains schema')
          end
        end

        context 'when items schema is referenced' do

          it 'does not raise an exception if a contains referenced value is valid' do
            const = const_schema['const']
            items = Array.new(5 + rand(10), {})
            items[rand(items.length - 1)] = { const: const }
            instance = { ref_contains: items }
            expect { validator.validate_instance(instance, data_type: data_type) }.not_to raise_error
          end

          it 'does not report errors if a Mongoff contains referenced value is valid' do
            const = const_schema['const']
            items = Array.new(5 + rand(10), {})
            items[rand(items.length - 1)] = { const: const }
            instance = data_type.new_from(
              ref_contains: items
            )
            validator.soft_validates(instance)
            expect(instance.errors.empty?).to be true
          end

          it 'raises an exception if a contains referenced value is not valid' do
            instance = {
              ref_contains: Array.new(5 + rand(10), {})
            }
            expect {
              validator.validate_instance(instance, data_type: data_type)
            }.to raise_error(::Mongoff::Validator::Error, "Value '#/ref_contains' have no items matching the contains schema")
          end

          it 'reports errors if a Mongoff contains referenced value is not valid' do
            instance = data_type.new_from(
              ref_contains: Array.new(5 + rand(10), {})
            )
            validator.soft_validates(instance)
            expect(instance.errors[:ref_contains]).to include('have no items matching the contains schema')
          end
        end
      end

      context 'when validating keyword maxContains' do

        it 'does not raise an exception if a maxContains value is valid' do
          const = const_schema['const']
          indices = Array(1..(max_contains + 1 + rand(10)))
          items = indices.map { |i| "not #{const} #{i}" }
          indices.take(max_contains - 1 - rand(3)).each { |i| items[i] = const }
          instance = { maxContains: items }
          expect { validator.validate_instance(instance, data_type: data_type) }.not_to raise_error
        end

        it 'does not report errors if a Mongoff maxContains value is valid' do
          const = const_schema['const']
          indices = Array(1..(max_contains + 1 + rand(10)))
          items = indices.map { |i| "not #{const} #{i}" }
          indices.take(max_contains - 1 - rand(3)).each { |i| items[i] = const }
          instance = data_type.new_from(
            maxContains: items
          )
          validator.soft_validates(instance)
          expect(instance.errors.empty?).to be true
        end

        it 'does not raise an exception if a maxContains value is maximum' do
          const = const_schema['const']
          indices = Array(1..(max_contains + 1 + rand(10)))
          items = indices.map { |i| "not #{const} #{i}" }
          indices.take(max_contains).each { |i| items[i] = const }
          instance = { maxContains: items }
          expect { validator.validate_instance(instance, data_type: data_type) }.not_to raise_error
        end

        it 'does not report errors if a Mongoff maxContains value is maximum' do
          const = const_schema['const']
          indices = Array(1..(max_contains + 1 + rand(10)))
          items = indices.map { |i| "not #{const} #{i}" }
          indices.take(max_contains).each { |i| items[i] = const }
          instance = data_type.new_from(
            maxContains: items
          )
          validator.soft_validates(instance)
          expect(instance.errors.empty?).to be true
        end

        it 'raises an exception if a maxContains value is not valid' do
          const = const_schema['const']
          indices = Array(1..(max_contains + 5 + rand(5)))
          items = indices.map { |i| "not #{const} #{i}" }
          indices.take(contains = max_contains + 1 + rand(4)).each { |i| items[i] = const }
          instance = {
            maxContains: items
          }
          expect {
            validator.validate_instance(instance, data_type: data_type)
          }.to raise_error(::Mongoff::Validator::Error, "Value '#/maxContains' has too much items (#{contains} for #{max_contains} max) matching the contains schema")
        end

        it 'reports errors if a Mongoff maxContains value is not valid' do
          const = const_schema['const']
          indices = Array(1..(max_contains + 5 + rand(5)))
          items = indices.map { |i| "not #{const} #{i}" }
          indices.take(contains = max_contains + 1 + rand(4)).each { |i| items[i] = const }
          instance = data_type.new_from(
            maxContains: items
          )
          validator.soft_validates(instance)
          expect(instance.errors[:maxContains]).to include("has too much items (#{contains} for #{max_contains} max) matching the contains schema")
        end
      end

      context 'when validating keyword minContains' do

        it 'does not raise an exception if a minContains value is valid' do
          const = const_schema['const']
          indices = Array(1..(min_contains + 5 + rand(5)))
          items = indices.map { |i| "not #{const} #{i}" }
          indices.take(min_contains + 1 + rand(4)).each { |i| items[i] = const }
          instance = { minContains: items }
          expect { validator.validate_instance(instance, data_type: data_type) }.not_to raise_error
        end

        it 'does not report errors if a Mongoff minContains value is valid' do
          const = const_schema['const']
          indices = Array(1..(min_contains + 5 + rand(5)))
          items = indices.map { |i| "not #{const} #{i}" }
          indices.take(min_contains + 1 + rand(4)).each { |i| items[i] = const }
          instance = data_type.new_from(
            minContains: items
          )
          validator.soft_validates(instance)
          expect(instance.errors.empty?).to be true
        end

        it 'does not raise an exception if a minContains value is minimum' do
          const = const_schema['const']
          indices = Array(1..(min_contains + 5 + rand(5)))
          items = indices.map { |i| "not #{const} #{i}" }
          indices.take(min_contains).each { |i| items[i] = const }
          instance = { minContains: items }
          expect { validator.validate_instance(instance, data_type: data_type) }.not_to raise_error
        end

        it 'does not report errors if a Mongoff minContains value is minimum' do
          const = const_schema['const']
          indices = Array(1..(min_contains + 1 + rand(10)))
          items = indices.map { |i| "not #{const} #{i}" }
          indices.take(min_contains).each { |i| items[i] = const }
          instance = data_type.new_from(
            minContains: items
          )
          validator.soft_validates(instance)
          expect(instance.errors.empty?).to be true
        end

        it 'raises an exception if a minContains value is not valid' do
          const = const_schema['const']
          indices = Array(1..(min_contains + 5 + rand(5)))
          items = indices.map { |i| "not #{const} #{i}" }
          indices.take(contains = min_contains - 1 - rand(4)).each { |i| items[i] = const }
          instance = {
            minContains: items
          }
          expect {
            validator.validate_instance(instance, data_type: data_type)
          }.to raise_error(::Mongoff::Validator::Error, "Value '#/minContains' has too few items (#{contains} for #{min_contains} min) matching the contains schema")
        end

        it 'reports errors if a Mongoff minContains value is not valid' do
          const = const_schema['const']
          indices = Array(1..(min_contains + 5 + rand(5)))
          items = indices.map { |i| "not #{const} #{i}" }
          indices.take(contains = min_contains - 1 - rand(4)).each { |i| items[i] = const }
          instance = data_type.new_from(
            minContains: items
          )
          validator.soft_validates(instance)
          expect(instance.errors[:minContains]).to include("has too few items (#{contains} for #{min_contains} min) matching the contains schema")
        end
      end
    end

    context 'when validating keywords for Applying Subschemas to Objects' do

      context 'when validating keyword properties' do

        context 'when properties schema is embedded' do

          it 'does not raise an exception if a properties embedded value is valid' do
            instance = { embedded_properties: sample_instance }
            expect { validator.validate_instance(instance, data_type: data_type) }.not_to raise_error
          end

          it 'does not report errors if a Mongoff properties embedded value is valid' do
            instance = data_type.new_from(
              embedded_properties: sample_instance
            )
            validator.soft_validates(instance)
            expect(instance.errors.empty?).to be true
          end

          it 'raises an exception if a properties embedded value is not valid' do
            obj = sample_instance
            obj[:const] = "not #{const_schema['const']}"
            instance = { embedded_properties: sample_instance }
            expect {
              validator.validate_instance(instance, data_type: data_type)
            }.to raise_error(::Mongoff::Validator::Error, "Value '#/embedded_properties/const' is not the const value '#{const_schema['const']}'")
          end

          it 'reports errors if a Mongoff properties embedded value is not valid' do
            obj = sample_instance
            obj[:const] = "not #{const_schema['const']}"
            instance = data_type.new_from(
              embedded_properties: obj
            )
            validator.soft_validates(instance)
            expect(instance.embedded_properties.errors[:const]).to include("is not the const value '#{const_schema['const']}'")
          end
        end

        context 'when properties schema is referenced' do

          it 'does not raise an exception if a properties referenced value is valid' do
            instance = { ref_properties: sample_instance }
            expect { validator.validate_instance(instance, data_type: data_type) }.not_to raise_error
          end

          it 'does not report errors if a Mongoff properties referenced value is valid' do
            instance = data_type.new_from(
              ref_properties: sample_instance
            )
            validator.soft_validates(instance)
            expect(instance.errors.empty?).to be true
          end

          it 'raises an exception if a properties referenced value is not valid' do
            obj = sample_instance
            obj[:const] = "not #{const_schema['const']}"
            instance = { ref_properties: sample_instance }
            expect {
              validator.validate_instance(instance, data_type: data_type)
            }.to raise_error(::Mongoff::Validator::Error, "Value '#/ref_properties/const' is not the const value '#{const_schema['const']}'")
          end

          it 'reports errors if a Mongoff properties referenced value is not valid' do
            obj = sample_instance
            obj[:const] = "not #{const_schema['const']}"
            instance = data_type.new_from(
              ref_properties: obj
            )
            validator.soft_validates(instance)
            expect(instance.ref_properties.errors[:const]).to include("is not the const value '#{const_schema['const']}'")
          end
        end

        context 'when properties schema is an embedded array' do

          it 'does not raise an exception if a properties embedded array value is valid' do
            instance = { embedded_array_properties: [sample_instance] }
            expect { validator.validate_instance(instance, data_type: data_type) }.not_to raise_error
          end

          it 'does not report errors if a Mongoff properties embedded array value is valid' do
            instance = data_type.new_from(
              embedded_array_properties: [sample_instance]
            )
            validator.soft_validates(instance)
            expect(instance.errors.empty?).to be true
          end

          it 'raises an exception if a properties embedded array value is not valid' do
            obj = sample_instance
            obj[:const] = "not #{const_schema['const']}"
            instance = { embedded_array_properties: [sample_instance] }
            expect {
              validator.validate_instance(instance, data_type: data_type)
            }.to raise_error(::Mongoff::Validator::Error, "Value '#/embedded_array_properties[0]/const' is not the const value '#{const_schema['const']}'")
          end

          it 'reports errors if a Mongoff properties embedded array value is not valid' do
            obj = sample_instance
            obj[:const] = "not #{const_schema['const']}"
            instance = data_type.new_from(
              embedded_array_properties: [obj]
            )
            validator.soft_validates(instance)
            expect(instance.embedded_array_properties[0].errors[:const]).to include("is not the const value '#{const_schema['const']}'")
          end
        end

        context 'when properties schema is referenced array' do

          it 'does not raise an exception if a properties referenced array value is valid' do
            instance = { ref_array_properties: [sample_instance] }
            expect { validator.validate_instance(instance, data_type: data_type) }.not_to raise_error
          end

          it 'does not report errors if a Mongoff properties referenced array value is valid' do
            instance = data_type.new_from(
              ref_array_properties: [sample_instance]
            )
            validator.soft_validates(instance)
            expect(instance.errors.empty?).to be true
          end

          it 'raises an exception if a properties referenced array value is not valid' do
            obj = sample_instance
            obj[:const] = "not #{const_schema['const']}"
            instance = { ref_array_properties: [sample_instance] }
            expect {
              validator.validate_instance(instance, data_type: data_type)
            }.to raise_error(::Mongoff::Validator::Error, "Value '#/ref_array_properties[0]/const' is not the const value '#{const_schema['const']}'")
          end

          it 'reports errors if a Mongoff properties referenced array value is not valid' do
            obj = sample_instance
            obj[:const] = "not #{const_schema['const']}"
            instance = data_type.new_from(
              ref_array_properties: [obj]
            )
            validator.soft_validates(instance)
            expect(instance.ref_array_properties[0].errors[:const]).to include("is not the const value '#{const_schema['const']}'")
          end
        end
      end

      context 'when validating keyword patternProperties' do

        it 'does not raise an exception if pattern properties are not present' do
          expect {
            validator.validate_instance(sample_instance, data_type: data_type)
          }.not_to raise_error
        end

        it 'does not raise an exception if valid pattern properties are present' do
          instance = sample_instance.merge(
            support_email: 'support@cenit.io',
            company_email: 'support@cenit.io'
          )
          expect {
            validator.validate_instance(instance, data_type: data_type)
          }.not_to raise_error
        end

        it 'does not report errors if a Mongoff pattern properties are not present' do
          instance = data_type.new_from(sample_instance)
          validator.soft_validates(instance)
          expect(instance.errors.empty?).to be true
        end

        it 'does not report errors if a Mongoff pattern properties are present' do
          obj = sample_instance.merge(
            support_email: 'support@cenit.io',
            company_email: 'support@cenit.io'
          )
          instance = data_type.new_from(obj)
          validator.soft_validates(instance)
          expect(instance.errors.empty?).to be true
        end

        it 'raises an exception if pattern properties are not valid' do
          instance = sample_instance.merge(
            support_email: 'support@cenit.io',
            company_email: 'not an email'
          )
          expect {
            validator.validate_instance(instance, data_type: data_type)
          }.to raise_error(::Mongoff::Validator::Error, "Value '#/company_email' is not a valid email address")
        end

        it 'reports errors if a Mongoff pattern properties are not valid' do
          obj = sample_instance.merge(
            support_email: 'support@cenit.io',
            company_email: 'not an email'
          )
          instance = data_type.new_from(obj)
          validator.soft_validates(instance)
          expect(instance.errors[:company_email]).to include('is not a valid email address')
        end

        it 'raises an exception if an embedded pattern properties are not valid' do
          instance = {
            embedded_properties: sample_instance.merge(
              support_email: 'support@cenit.io',
              company_email: 'not an email'
            )
          }
          expect {
            validator.validate_instance(instance, data_type: data_type)
          }.to raise_error(::Mongoff::Validator::Error, "Value '#/embedded_properties/company_email' is not a valid email address")
        end

        it 'reports errors if a Mongoff embedded pattern properties are not valid' do
          obj = {
            embedded_properties: sample_instance.merge(
              support_email: 'support@cenit.io',
              company_email: 'not an email'
            )
          }
          instance = data_type.new_from(obj)
          validator.soft_validates(instance)
          expect(instance.embedded_properties.errors[:company_email]).to include('is not a valid email address')
        end

        it 'raises an exception if a referenced pattern properties are not valid' do
          instance = {
            ref_properties: sample_instance.merge(
              support_email: 'support@cenit.io',
              company_email: 'not an email'
            )
          }
          expect {
            validator.validate_instance(instance, data_type: data_type)
          }.to raise_error(::Mongoff::Validator::Error, "Value '#/ref_properties/company_email' is not a valid email address")
        end

        it 'reports errors if a Mongoff referenced pattern properties are not valid' do
          obj = {
            ref_properties: sample_instance.merge(
              support_email: 'support@cenit.io',
              company_email: 'not an email'
            )
          }
          instance = data_type.new_from(obj)
          validator.soft_validates(instance)
          expect(instance.ref_properties.errors[:company_email]).to include('is not a valid email address')
        end

        it 'raises an exception if an array of embedded pattern properties is not valid' do
          instance = {
            embedded_array_properties: [
              sample_instance.merge(
                support_email: 'support@cenit.io',
                company_email: 'not an email'
              )
            ]
          }
          expect {
            validator.validate_instance(instance, data_type: data_type)
          }.to raise_error(::Mongoff::Validator::Error, "Value '#/embedded_array_properties[0]/company_email' is not a valid email address")
        end

        it 'reports errors if a Mongoff an array of embedded pattern properties is not valid' do
          obj = {
            embedded_array_properties: [
              sample_instance.merge(
                support_email: 'support@cenit.io',
                company_email: 'not an email'
              )
            ]
          }
          instance = data_type.new_from(obj)
          validator.soft_validates(instance)
          expect(instance.embedded_array_properties[0].errors[:company_email]).to include('is not a valid email address')
        end

        it 'raises an exception if an array of referenced pattern properties is not valid' do
          instance = {
            ref_array_properties: [
              sample_instance.merge(
                support_email: 'support@cenit.io',
                company_email: 'not an email'
              )
            ]
          }
          expect {
            validator.validate_instance(instance, data_type: data_type)
          }.to raise_error(::Mongoff::Validator::Error, "Value '#/ref_array_properties[0]/company_email' is not a valid email address")
        end

        it 'reports errors if a Mongoff an array of referenced pattern properties is not valid' do
          obj = {
            ref_array_properties: [
              sample_instance.merge(
                support_email: 'support@cenit.io',
                company_email: 'not an email'
              )
            ]
          }
          instance = data_type.new_from(obj)
          validator.soft_validates(instance)
          expect(instance.ref_array_properties[0].errors[:company_email]).to include('is not a valid email address')
        end
      end

      context 'when validating keyword additionalProperties' do

        it 'does not raise an exception if additional properties are allowed' do
          instance = sample_instance.merge(
            an_additional_property: true,
            another_additional_property: true
          )
          expect {
            validator.validate_instance(instance, data_type: data_type_with_additional_props_true)
          }.not_to raise_error
        end

        it 'does not report errors if a Mongoff additional properties are allowed' do
          obj = sample_instance.merge(
            an_additional_property: true,
            another_additional_property: true
          )
          instance = data_type_with_additional_props_true.new_from(obj)
          validator.soft_validates(instance)
          expect(instance.errors.empty?).to be true
        end

        it 'raises an exception if additional properties are not allowed' do
          instance = sample_instance.merge(
            an_additional_property: true
          )
          expect {
            validator.validate_instance(instance, data_type: data_type_with_additional_props_false)
          }.to raise_error(::Mongoff::Validator::Error, "Value '#/an_additional_property' is not allowed (against additional properties schema)")
        end

        it 'reports errors if a Mongoff additional properties are not allowed' do
          n = 2 + rand(5)
          obj = sample_instance
          n.downto(1) { |i| obj["an_additional_property_#{i}"] = true }
          instance = data_type_with_additional_props_false.new_from(obj)
          validator.soft_validates(instance)
          n.downto(1) do |i|
            expect(instance.errors["an_additional_property_#{i}"]).to include('is not allowed (against additional properties schema)')
          end
        end

        it 'does not raise an exception if additional properties are valid' do
          instance = sample_instance.merge(
            additional_property_1: const_schema['const'],
            additional_property_2: const_schema['const']
          )
          expect {
            validator.validate_instance(instance, data_type: data_type)
          }.not_to raise_error
        end

        it 'does not report errors if a Mongoff additional properties are valid' do
          obj = sample_instance.merge(
            additional_property_1: const_schema['const'],
            additional_property_2: const_schema['const']
          )
          instance = data_type.new_from(obj)
          validator.soft_validates(instance)
          expect(instance.errors.empty?).to be true
        end

        it 'raises an exception if additional properties are not valid' do
          const = const_schema['const']
          instance = sample_instance.merge(
            additional_property_1: const,
            additional_property_2: "not #{const}"
          )
          expect {
            validator.validate_instance(instance, data_type: data_type)
          }.to raise_error(::Mongoff::Validator::Error, "Value '#/additional_property_2' is not the const value '#{const}' (against additional properties schema)")
        end

        it 'reports errors if a Mongoff additional properties are not valid' do
          const = const_schema['const']
          obj = sample_instance.merge(
            additional_property_1: const,
            additional_property_2: "not #{const}"
          )
          instance = data_type.new_from(obj)
          validator.soft_validates(instance)
          expect(instance.errors[:additional_property_2]).to include("is not the const value '#{const}' (against additional properties schema)")
        end

        it 'raises an exception if an embedded additional properties are not valid' do
          const = const_schema['const']
          instance = {
            embedded_properties: sample_instance.merge(
              additional_property_1: const,
              additional_property_2: "not #{const}"
            )
          }
          expect {
            validator.validate_instance(instance, data_type: data_type)
          }.to raise_error(::Mongoff::Validator::Error, "Value '#/embedded_properties/additional_property_2' is not the const value '#{const}' (against additional properties schema)")
        end

        it 'reports errors if a Mongoff embedded additional properties are not valid' do
          const = const_schema['const']
          obj = {
            embedded_properties: sample_instance.merge(
              additional_property_1: const,
              additional_property_2: "not #{const}"
            )
          }
          instance = data_type.new_from(obj)
          validator.soft_validates(instance)
          expect(instance.embedded_properties.errors[:additional_property_2]).to include("is not the const value '#{const}' (against additional properties schema)")
        end

        it 'raises an exception if a referenced additional properties are not valid' do
          const = const_schema['const']
          instance = {
            ref_properties: sample_instance.merge(
              additional_property_1: const,
              additional_property_2: "not #{const}"
            )
          }
          expect {
            validator.validate_instance(instance, data_type: data_type)
          }.to raise_error(::Mongoff::Validator::Error, "Value '#/ref_properties/additional_property_2' is not the const value '#{const}' (against additional properties schema)")
        end

        it 'reports errors if a Mongoff referenced additional properties are not valid' do
          const = const_schema['const']
          obj = {
            ref_properties: sample_instance.merge(
              additional_property_1: const,
              additional_property_2: "not #{const}"
            )
          }
          instance = data_type.new_from(obj)
          validator.soft_validates(instance)
          expect(instance.ref_properties.errors[:additional_property_2]).to include("is not the const value '#{const}' (against additional properties schema)")
        end

        it 'raises an exception if an array of embedded additional properties is not valid' do
          const = const_schema['const']
          instance = {
            embedded_array_properties: [
              sample_instance.merge(
                additional_property_1: const,
                additional_property_2: "not #{const}"
              )
            ]
          }
          expect {
            validator.validate_instance(instance, data_type: data_type)
          }.to raise_error(::Mongoff::Validator::Error, "Value '#/embedded_array_properties[0]/additional_property_2' is not the const value '#{const}' (against additional properties schema)")
        end

        it 'reports errors if a Mongoff an array of embedded additional properties is not valid' do
          const = const_schema['const']
          obj = {
            embedded_array_properties: [
              sample_instance.merge(
                additional_property_1: const,
                additional_property_2: "not #{const}"
              )
            ]
          }
          instance = data_type.new_from(obj)
          validator.soft_validates(instance)
          expect(instance.embedded_array_properties[0].errors[:additional_property_2]).to include("is not the const value '#{const}' (against additional properties schema)")
        end

        it 'raises an exception if an array of referenced additional properties is not valid' do
          const = const_schema['const']
          instance = {
            ref_array_properties: [
              sample_instance.merge(
                additional_property_1: const,
                additional_property_2: "not #{const}"
              )
            ]
          }
          expect {
            validator.validate_instance(instance, data_type: data_type)
          }.to raise_error(::Mongoff::Validator::Error, "Value '#/ref_array_properties[0]/additional_property_2' is not the const value '#{const}' (against additional properties schema)")
        end

        it 'reports errors if a Mongoff an array of referenced additional properties is not valid' do
          const = const_schema['const']
          obj = {
            ref_array_properties: [
              sample_instance.merge(
                additional_property_1: const,
                additional_property_2: "not #{const}"
              )
            ]
          }
          instance = data_type.new_from(obj)
          validator.soft_validates(instance)
          expect(instance.ref_array_properties[0].errors[:additional_property_2]).to include("is not the const value '#{const}' (against additional properties schema)")
        end
      end

      context 'when validating keyword propertyNames' do

        it 'raises an exception if property names are not valid' do
          wrong_name = 'an_additional_property_with_a_very_long_long_name_' + ('x' * property_names_max_length)
          instance = sample_instance.merge(
            wrong_name => const_schema['const']
          )
          expect {
            validator.validate_instance(instance, data_type: data_type)
          }.to raise_error(::Mongoff::Validator::Error, "Property '#/#{wrong_name}' name does not match property names schema: is too long (#{wrong_name.length} of #{property_names_max_length} max)")
        end

        it 'reports errors if a Mongoff property names are not valid' do
          wrong_name_prefix = 'an_additional_property_with_a_very_long_long_name_' + ('x' * property_names_max_length)
          n = 2 + rand(5)
          obj = sample_instance
          n.downto(1) { |i| obj["#{wrong_name_prefix}_#{i}"] = const_schema['const'] }
          instance = data_type.new_from(obj)
          validator.soft_validates(instance)
          n.downto(1) do |i|
            expect(instance.errors["#{wrong_name_prefix}_#{i}"]).to include("name does not match the property names schema: is too long (#{wrong_name_prefix.length + 2} of #{property_names_max_length} max)")
          end
        end
      end

      context 'when validating keyword maxProperties' do

        context 'when object schema is embedded' do

          it 'does not raise an exception if a maxProperties instance size is not maximum' do
            obj = sample_instance
            obj = obj.keys.take(max_properties - 1 - rand(max_properties / 2)).map do |key|
              [key, obj[key]]
            end.to_h
            instance = { embedded_maxProperties: obj }
            expect { validator.validate_instance(instance, data_type: data_type) }.not_to raise_error
          end

          it 'does not raise an exception if a Mongoff maxProperties instance size is not maximum' do
            obj = sample_instance
            obj = obj.keys.take(max_properties - 1 - rand(max_properties / 2)).map do |key|
              [key, obj[key]]
            end.to_h
            instance = data_type.new_from(embedded_maxProperties: obj)
            expect { validator.validate_instance(instance, data_type: data_type) }.not_to raise_error
          end

          it 'does not raise an exception if a maxProperties instance size is maximum' do
            obj = sample_instance
            obj = obj.keys.take(max_properties).map do |key|
              [key, obj[key]]
            end.to_h
            instance = { embedded_maxProperties: obj }
            expect { validator.validate_instance(instance, data_type: data_type) }.not_to raise_error
          end

          it 'does not raise an exception if a Mongoff maxProperties instance size is maximum' do
            obj = sample_instance
            obj = obj.keys.take(max_properties).map do |key|
              [key, obj[key]]
            end.to_h
            instance = data_type.new_from(embedded_maxProperties: obj)
            expect { validator.validate_instance(instance, data_type: data_type) }.not_to raise_error
          end

          it 'raises an exception if a maxProperties instance overflows' do
            obj = sample_instance
            obj = obj.keys.take(max_properties + 1 + rand(max_properties / 2)).map do |key|
              [key, obj[key]]
            end.to_h
            instance = { embedded_maxProperties: obj }
            expect {
              validator.validate_instance(instance, data_type: data_type)
            }.to raise_error(::Mongoff::Validator::Error, "Value '#/embedded_maxProperties' has too many properties (#{obj.size} of #{max_properties} max)")
          end

          it 'raises an exception if a Mongoff maxProperties instance overflows' do
            obj = sample_instance
            obj = obj.keys.take(max_properties + 1 + rand(max_properties / 2)).map do |key|
              [key, obj[key]]
            end.to_h
            instance = data_type.new_from(embedded_maxProperties: obj)
            validator.soft_validates(instance)
            expect(instance.errors[:embedded_maxProperties]).to include("has too many properties (#{obj.size} of #{max_properties} max)")
          end
        end

        context 'when object schema is referenced' do

          it 'does not raise an exception if a maxProperties instance size is not maximum' do
            obj = sample_instance
            obj = obj.keys.take(max_properties - 1 - rand(max_properties / 2)).map do |key|
              [key, obj[key]]
            end.to_h
            instance = { ref_maxProperties: obj }
            expect { validator.validate_instance(instance, data_type: data_type) }.not_to raise_error
          end

          it 'does not raise an exception if a Mongoff maxProperties instance size is not maximum' do
            obj = sample_instance
            obj = obj.keys.take(max_properties - 1 - rand(max_properties / 2)).map do |key|
              [key, obj[key]]
            end.to_h
            instance = data_type.new_from_json(ref_maxProperties: obj)
            expect { validator.validate_instance(instance, data_type: data_type) }.not_to raise_error
          end

          it 'does not raise an exception if a maxProperties instance size is maximum' do
            obj = sample_instance
            obj = obj.keys.take(max_properties).map do |key|
              [key, obj[key]]
            end.to_h
            instance = { ref_maxProperties: obj }
            expect { validator.validate_instance(instance, data_type: data_type) }.not_to raise_error
          end

          it 'does not raise an exception if a Mongoff maxProperties instance size is maximum' do
            obj = sample_instance
            obj = obj.keys.take(max_properties).map do |key|
              [key, obj[key]]
            end.to_h
            instance = data_type.new_from_json(ref_maxProperties: obj)
            expect { validator.validate_instance(instance, data_type: data_type) }.not_to raise_error
          end

          it 'raises an exception if a maxProperties instance overflows' do
            obj = sample_instance
            obj = obj.keys.take(max_properties + 1 + rand(max_properties / 2)).map do |key|
              [key, obj[key]]
            end.to_h
            instance = { ref_maxProperties: obj }
            expect {
              validator.validate_instance(instance, data_type: data_type)
            }.to raise_error(::Mongoff::Validator::Error, "Value '#/ref_maxProperties' has too many properties (#{obj.size} of #{max_properties} max)")
          end

          it 'raises an exception if a Mongoff maxProperties instance overflows' do
            obj = sample_instance
            obj = obj.keys.take(max_properties + 1 + rand(max_properties / 2)).map do |key|
              [key, obj[key]]
            end.to_h
            instance = data_type.new_from_json(ref_maxProperties: obj)
            validator.soft_validates(instance)
            expect(instance.errors[:ref_maxProperties]).to include("has too many properties (#{obj.size} of #{max_properties} max)")
          end
        end
      end

      context 'when validating keyword minProperties' do

        context 'when object schema is embedded' do

          it 'does not raise an exception if a minProperties instance size is not minimum' do
            obj = sample_instance
            obj = obj.keys.take(min_properties + 1 + rand(min_properties)).map do |key|
              [key, obj[key]]
            end.to_h
            instance = { embedded_minProperties: obj }
            expect { validator.validate_instance(instance, data_type: data_type) }.not_to raise_error
          end

          it 'does not raise an exception if a Mongoff minProperties instance size is not minimum' do
            obj = sample_instance
            obj = obj.keys.take(min_properties + 1 + rand(min_properties)).map do |key|
              [key, obj[key]]
            end.to_h
            instance = data_type.new_from(embedded_minProperties: obj)
            expect { validator.validate_instance(instance, data_type: data_type) }.not_to raise_error
          end

          it 'does not raise an exception if a minProperties instance size is minimum' do
            obj = sample_instance
            obj = obj.keys.take(min_properties).map do |key|
              [key, obj[key]]
            end.to_h
            instance = { embedded_minProperties: obj }
            expect { validator.validate_instance(instance, data_type: data_type) }.not_to raise_error
          end

          it 'does not raise an exception if a Mongoff minProperties instance size is minimum' do
            obj = sample_instance
            obj = obj.keys.take(min_properties).map do |key|
              [key, obj[key]]
            end.to_h
            instance = data_type.new_from(embedded_minProperties: obj)
            expect { validator.validate_instance(instance, data_type: data_type) }.not_to raise_error
          end

          it 'raises an exception if a minProperties instance underflows' do
            obj = sample_instance
            obj = obj.keys.take(min_properties - 1 - rand(min_properties / 2)).map do |key|
              [key, obj[key]]
            end.to_h
            instance = { embedded_minProperties: obj }
            expect {
              validator.validate_instance(instance, data_type: data_type)
            }.to raise_error(::Mongoff::Validator::Error, "Value '#/embedded_minProperties' has too few properties (#{obj.size} for #{min_properties} min)")
          end

          it 'raises an exception if a Mongoff minProperties instance underflows' do
            obj = sample_instance
            obj = obj.keys.take(min_properties - 1 - rand(min_properties / 2)).map do |key|
              [key, obj[key]]
            end.to_h
            instance = data_type.new_from(embedded_minProperties: obj)
            validator.soft_validates(instance)
            expect(instance.errors[:embedded_minProperties]).to include("has too few properties (#{obj.size} for #{min_properties} min)")
          end
        end

        context 'when object schema is referenced' do

          it 'does not raise an exception if a minProperties instance size is not minimum' do
            obj = sample_instance
            obj = obj.keys.take(min_properties + 1 + rand(min_properties)).map do |key|
              [key, obj[key]]
            end.to_h
            instance = { ref_minProperties: obj }
            expect { validator.validate_instance(instance, data_type: data_type) }.not_to raise_error
          end

          it 'does not raise an exception if a Mongoff minProperties instance size is not minimum' do
            obj = sample_instance
            obj = obj.keys.take(min_properties + 1 + rand(min_properties)).map do |key|
              [key, obj[key]]
            end.to_h
            instance = data_type.new_from_json(ref_minProperties: obj)
            expect { validator.validate_instance(instance, data_type: data_type) }.not_to raise_error
          end

          it 'does not raise an exception if a minProperties instance size is minimum' do
            obj = sample_instance
            obj = obj.keys.take(min_properties).map do |key|
              [key, obj[key]]
            end.to_h
            instance = { ref_minProperties: obj }
            expect { validator.validate_instance(instance, data_type: data_type) }.not_to raise_error
          end

          it 'does not raise an exception if a Mongoff minProperties instance size is minimum' do
            obj = sample_instance
            obj = obj.keys.take(min_properties).map do |key|
              [key, obj[key]]
            end.to_h
            instance = data_type.new_from_json(ref_minProperties: obj)
            expect { validator.validate_instance(instance, data_type: data_type) }.not_to raise_error
          end

          it 'raises an exception if a minProperties instance underflows' do
            obj = sample_instance
            obj = obj.keys.take(min_properties - 1 - rand(min_properties / 2)).map do |key|
              [key, obj[key]]
            end.to_h
            instance = { ref_minProperties: obj }
            expect {
              validator.validate_instance(instance, data_type: data_type)
            }.to raise_error(::Mongoff::Validator::Error, "Value '#/ref_minProperties' has too few properties (#{obj.size} for #{min_properties} min)")
          end

          it 'raises an exception if a Mongoff minProperties instance underflows' do
            obj = sample_instance
            obj = obj.keys.take(min_properties - 1 - rand(min_properties / 2)).map do |key|
              [key, obj[key]]
            end.to_h
            instance = data_type.new_from_json(ref_minProperties: obj)
            validator.soft_validates(instance)
            expect(instance.errors[:ref_minProperties]).to include("has too few properties (#{obj.size} for #{min_properties} min)")
          end
        end
      end

      context 'when validating keyword required' do

        it 'does not raise an exception if a required instance is valid' do
          expect {
            validator.validate_instance(sample_instance, data_type: data_type_with_required)
          }.not_to raise_error
        end

        it 'does not raise an exception if a Mongoff required instance is valid' do
          instance = data_type_with_required.new_from_json(sample_instance)
          expect {
            validator.validate_instance(instance)
          }.not_to raise_error
        end

        it 'raises an exception if a required property is missing' do
          instance = sample_instance
          missing_prop = required_props.sample
          instance.delete(missing_prop.to_sym)
          expect {
            validator.validate_instance(instance, data_type: data_type_with_required)
          }.to raise_error(::Mongoff::Validator::Error, "Property #{missing_prop} is required")
        end

        it 'raises an exception if multiple required properties are missing' do
          instance = sample_instance
          missing_props = required_props.take(2 + rand(required_props.length - 2))
          missing_props.each { |p| instance.delete(p.to_sym) }
          expect {
            validator.validate_instance(instance, data_type: data_type_with_required)
          }.to raise_error(::Mongoff::Validator::Error, "Properties #{missing_props.to_sentence} are required")
        end

        it 'reports errors if a Mongoff required instance is not valid' do
          obj = sample_instance
          missing_props = required_props.take(1 + rand(required_props.length - 1))
          missing_props.each { |p| obj.delete(p.to_sym) }
          instance = data_type_with_required.new_from(obj)
          validator.soft_validates(instance)
          missing_props.each do |p|
            expect(instance.errors[p]).to include('is required')
          end
        end
      end

      context 'when validating keyword dependentRequired' do

        it 'does not raise an exception if a dependentRequired instance is valid' do
          expect {
            validator.validate_instance(sample_instance, data_type: data_type_with_dependent_required)
          }.not_to raise_error
        end

        it 'does not raise an exception if a Mongoff dependentRequired instance is valid' do
          instance = data_type_with_dependent_required.new_from_json(sample_instance)
          expect {
            validator.validate_instance(instance)
          }.not_to raise_error
        end

        it 'raises an exception if a dependentRequired property is missing' do
          instance = sample_instance
          instance.delete(p_1.to_sym)
          expect {
            validator.validate_instance(instance, data_type: data_type_with_dependent_required)
          }.to raise_error(::Mongoff::Validator::Error, "Property #{p_1} is required because depending on #{p_0}")
        end


        it 'raises an exception if multiple dependentRequired properties are missing' do
          instance = sample_instance
          instance.delete(p_3.to_sym)
          instance.delete(p_4.to_sym)
          expect {
            validator.validate_instance(instance, data_type: data_type_with_dependent_required)
          }.to raise_error(::Mongoff::Validator::Error, "Properties #{p_3} and #{p_4} are required because depending on #{p_2}")
        end

        it 'reports errors if a Mongoff dependentRequired instance is not valid' do
          obj = sample_instance
          obj.delete(p_1.to_sym)
          obj.delete(p_3.to_sym)
          obj.delete(p_4.to_sym)
          instance = data_type_with_dependent_required.new_from(obj)
          validator.soft_validates(instance)
          {
            p_1 => p_0,
            p_3 => p_2,
            p_4 => p_2
          }.each do |p, d|
            expect(instance.errors[p]).to include("is required because depending on #{d}")
          end
        end
      end
    end

    context 'when validating Keywords for Applying Subschemas With Boolean Logic' do

      context 'when validating keyword allOf' do

        it 'does not raise an exception if an allOf instance value is valid' do
          n = ((minimum_schema['minimum'] + maximum_schema['maximum']) / 2).to_i
          instance = { allOf: n }
          expect {
            validator.validate_instance(instance, data_type: data_type)
          }.not_to raise_error
        end

        it 'does not report errors if a Mongoff allOf instance is valid' do
          n = ((minimum_schema['minimum'] + maximum_schema['maximum']) / 2).to_i
          instance = data_type.new_from(allOf: n)
          validator.soft_validates(instance)
          expect(instance.errors.empty?).to be true
        end

        it 'raises an exception if an allOf instance is not valid' do
          wrong_value = maximum_schema['maximum'] + 1
          instance = { allOf: wrong_value }
          expect {
            validator.validate_instance(instance, data_type: data_type)
          }.to raise_error(::Mongoff::Validator::Error, "Value '#/allOf' does not match allOf schema#1: expected to be maximum #{maximum_schema['maximum']}")
        end

        it 'raises an exception if a Mongoff allOf instance is not valid' do
          wrong_value = maximum_schema['maximum'] + 1
          instance = data_type.new_from(allOf: wrong_value)
          validator.soft_validates(instance)
          expect(instance.errors[:allOf]).to include("does not match allOf schema#1: expected to be maximum #{maximum_schema['maximum']}")
        end
      end

      context 'when validating keyword anyOf' do

        it 'does not raise an exception if an anyOf instance value is valid' do
          n = (maximum_schema['maximum'] % multiple_of + 2) * multiple_of
          instance = { anyOf: n }
          expect {
            validator.validate_instance(instance, data_type: data_type)
          }.not_to raise_error
        end

        it 'does not report errors if a Mongoff anyOf instance is valid' do
          n = (maximum_schema['maximum'] % multiple_of + 2) * multiple_of
          instance = data_type.new_from(anyOf: n)
          validator.soft_validates(instance)
          expect(instance.errors.empty?).to be true
        end

        it 'raises an exception if an anyOf instance is not valid' do
          wrong_value = (maximum_schema['maximum'] / multiple_of + 2) * multiple_of + 0.1
          instance = { anyOf: wrong_value }
          expect {
            validator.validate_instance(instance, data_type: data_type)
          }.to raise_error(::Mongoff::Validator::Error, "Value '#/anyOf' does not match any of the anyOf schemas")
        end

        it 'raises an exception if a Mongoff anyOf instance is not valid' do
          wrong_value = (maximum_schema['maximum'] / multiple_of + 2) * multiple_of + 0.1
          instance = data_type.new_from(anyOf: wrong_value)
          validator.soft_validates(instance)
          expect(instance.errors[:anyOf]).to include('does not match any of the anyOf schemas')
        end
      end
    end
  end
end
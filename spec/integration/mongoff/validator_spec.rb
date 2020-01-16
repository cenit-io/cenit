require 'spec_helper'

describe Mongoff::Validator do
  TEST_NAMESPACE = 'Mongoff Validator Test'

  TEST_SCHEMA = {
    type: 'object',
    properties: {
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
      object: {
        type: 'object'
      },
      array: {
        type: 'array'
      },

      color: {
        enum: %w(red green blue)
      },

      const: {
        const: rand(100)
      },

      multipleOf: {
        type: 'number',
        multipleOf: 5 + rand(10)
      },

      maximum: {
        type: 'number',
        maximum: 5 + rand(100)
      },

      minimum: {
        type: 'number',
        minimum: 5 + rand(100)
      },

      exclusiveMaximum: {
        type: 'number',
        exclusiveMaximum: 100 + rand(100)
      },

      exclusiveMinimum: {
        type: 'number',
        exclusiveMinimum: 100 - rand(100)
      }
    }
  }.deep_stringify_keys

  before :all do
    Setup::JsonDataType.create!(
      namespace: TEST_NAMESPACE,
      name: 'A',
      schema: TEST_SCHEMA
    )
  end

  let! :validator do
    ::Mongoff::Validator
  end

  let! :data_type do
    Setup::DataType.where(namespace: TEST_NAMESPACE, name: 'A').first
  end

  let :test_schema do
    data_type.schema
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
          schema = { maxLength: -rand(100) }
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
          schema = { minLength: -rand(100) }
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
          schema = { items: [validator, test_schema, validator] }
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
          schema = { maxItems: -rand(100) }
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
          schema = { minItems: -rand(100) }
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

        it 'does not raise an exception if the contains a valid schema' do
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
          schema = { maxContains: -rand(100) }
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
          schema = { minContains: -rand(100) }
          expect { validator.validate(schema) }.to raise_error(::Mongoff::Validator::Error)
        end
      end
    end

    context 'when validating keywords for Objects' do

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
          schema = { maxProperties: -rand(100) }
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
          schema = { minProperties: -rand(100) }
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
          }.to raise_error(::Mongoff::Validator::Error, "Value 'not null' of type String is not an instance of type null")
        end

        it 'does not raise an exception if the instance and type are boolean' do
          instance = { boolean: rand(2).to_b }
          expect { validator.validate_instance(instance, data_type: data_type) }.not_to raise_error
        end

        it 'raises an error when the expected instance type is boolean' do
          instance = { boolean: 'not boolean' }
          expect {
            validator.validate_instance(instance, data_type: data_type)
          }.to raise_error(::Mongoff::Validator::Error, "Value 'not boolean' of type String is not an instance of type boolean")
        end

        it 'does not raise an exception if the instance and type are object' do
          instance = { obj: {} }
          expect { validator.validate_instance(instance, data_type: data_type) }.not_to raise_error
        end

        it 'raises an error when the expected instance type is object' do
          instance = { obj: 'not object' }
          expect {
            validator.validate_instance(instance, data_type: data_type)
          }.to raise_error(::Mongoff::Validator::Error, "Value 'not object' of type String is not an instance of type object")
        end

        it 'does not raise an exception if the instance and type are array' do
          instance = { array: [] }
          expect { validator.validate_instance(instance, data_type: data_type) }.not_to raise_error
        end

        it 'raises an error when the expected instance type is array' do
          instance = { array: 'not array' }
          expect {
            validator.validate_instance(instance, data_type: data_type)
          }.to raise_error(::Mongoff::Validator::Error, "Value 'not array' of type String is not an instance of type array")
        end

        it 'does not raise an exception if the instance and type are number' do
          instance = { number: rand(10) + rand }
          expect { validator.validate_instance(instance, data_type: data_type) }.not_to raise_error
        end

        it 'raises an error when the expected instance type is number' do
          instance = { number: 'not number' }
          expect {
            validator.validate_instance(instance, data_type: data_type)
          }.to raise_error(::Mongoff::Validator::Error, "Value 'not number' of type String is not an instance of type number")
        end

        it 'does not raise an exception if the instance and type are integer' do
          instance = { integer: rand(10) }
          expect { validator.validate_instance(instance, data_type: data_type) }.not_to raise_error
        end

        it 'raises an error when the expected instance type is integer' do
          instance = { integer: 'not integer' }
          expect {
            validator.validate_instance(instance, data_type: data_type)
          }.to raise_error(::Mongoff::Validator::Error, "Value 'not integer' of type String is not an instance of type integer")
        end

        it 'does not raise an exception if the instance and type are string' do
          instance = { string: 'string' }
          expect { validator.validate_instance(instance, data_type: data_type) }.not_to raise_error
        end

        it 'raises an error when the expected instance type is string' do
          instance = { string: 123 }
          expect {
            validator.validate_instance(instance, data_type: data_type)
          }.to raise_error(::Mongoff::Validator::Error, "Value '123' of type Integer is not an instance of type string")
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
          }.to raise_error(::Mongoff::Validator::Error, "Value '#{wrong_value}' is not included in the enumeration")
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
          instance = { const: test_schema['properties']['const']['const'] }
          expect { validator.validate_instance(instance, data_type: data_type) }.not_to raise_error
        end

        it 'does not report errors if a Mongoff const instance is valid' do
          instance = data_type.new_from(const: test_schema['properties']['const']['const'])
          validator.soft_validates(instance)
          expect(instance.errors.empty?).to be true
        end

        it 'raises an error when a JSON const instance is not valid' do
          value = test_schema['properties']['const']['const']
          wrong_value = "#{value}_wrong"
          instance = { const: wrong_value }
          expect {
            validator.validate_instance(instance, data_type: data_type)
          }.to raise_error(::Mongoff::Validator::Error, "Value '#{wrong_value}' is not the const value '#{value}'")
        end

        it 'reports an error when a Mongoff const instance is not valid' do
          value = test_schema['properties']['const']['const']
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
          }.to raise_error(::Mongoff::Validator::Error, "Value '#{wrong_value}' is not multiple of #{factor}")
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
          instance = { maximum: test_schema['properties']['maximum']['maximum'] - rand(1) }
          expect { validator.validate_instance(instance, data_type: data_type) }.not_to raise_error
        end

        it 'does not report errors if a Mongoff maximum instance is valid' do
          instance = data_type.new_from(maximum: test_schema['properties']['maximum']['maximum'] - rand(1))
          validator.soft_validates(instance)
          expect(instance.errors.empty?).to be true
        end

        it 'raises an error when a JSON maximum instance is not valid' do
          maximum = test_schema['properties']['maximum']['maximum']
          wrong_value = maximum + 1 + rand(10)
          instance = { maximum: wrong_value }
          expect {
            validator.validate_instance(instance, data_type: data_type)
          }.to raise_error(::Mongoff::Validator::Error, "Value '#{wrong_value}' expected to be maximum #{maximum}")
        end

        it 'reports an error when a Mongoff maximum instance is not valid' do
          maximum = test_schema['properties']['maximum']['maximum']
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
          }.to raise_error(::Mongoff::Validator::Error, "Value '#{wrong_value}' must be strictly less than #{maximum}")
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
          }.to raise_error(::Mongoff::Validator::Error, "Value '#{maximum}' must be strictly less than #{maximum}")
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
          instance = { minimum: test_schema['properties']['minimum']['minimum'] + rand(1) }
          expect { validator.validate_instance(instance, data_type: data_type) }.not_to raise_error
        end

        it 'does not report errors if a Mongoff minimum instance is valid' do
          instance = data_type.new_from(minimum: test_schema['properties']['minimum']['minimum'] + rand(1))
          validator.soft_validates(instance)
          expect(instance.errors.empty?).to be true
        end

        it 'raises an error when a JSON minimum instance is not valid' do
          minimum = test_schema['properties']['minimum']['minimum']
          wrong_value = minimum - 1 - rand(10)
          instance = { minimum: wrong_value }
          expect {
            validator.validate_instance(instance, data_type: data_type)
          }.to raise_error(::Mongoff::Validator::Error, "Value '#{wrong_value}' expected to be minimum #{minimum}")
        end

        it 'reports an error when a Mongoff minimum instance is not valid' do
          minimum = test_schema['properties']['minimum']['minimum']
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
          }.to raise_error(::Mongoff::Validator::Error, "Value '#{wrong_value}' must be strictly greater than #{minimum}")
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
          }.to raise_error(::Mongoff::Validator::Error, "Value '#{minimum}' must be strictly greater than #{minimum}")
        end

        it 'reports an error when a Mongoff exclusiveMinimum instance is minimum' do
          minimum = test_schema['properties']['exclusiveMinimum']['exclusiveMinimum']
          instance = data_type.new_from(exclusiveMinimum: minimum)
          validator.soft_validates(instance)
          expect(instance.errors[:exclusiveMinimum]).to include("must be strictly greater than #{minimum}")
        end
      end
    end
  end
end
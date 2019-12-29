require 'spec_helper'

describe Mongoff::Validator do
  TEST_NAMESPACE = 'Mongoff Validator Test'

  SCHEMA = {
    type: 'object',
    properties: {
      null: {
        type: 'null'
      },
      boolean: {
        type: 'boolean'
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
        multipleOf: factor = rand(100) + 0.1,
        maximum: 10 * factor,
        minimum: 5 * factor
      },

      exclusiveMaxMin: {
        type: 'number',
        exclusiveMaximum: 100 + (delta = rand(100)),
        exclusiveMinimum: 100 - delta
      }
    },
    required: %w(name)
  }

  let! :validator do
    ::Mongoff::Validator
  end

  context 'when validating a schema' do

    it 'returns true if the schema is valid' do
      expect(validator.is_valid?(SCHEMA)).to be true
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
          schema = { items: SCHEMA }
          expect { validator.validate(schema) }.not_to raise_error
        end

        it 'does not raise an exception if the items value is an array of valid schemas' do
          schema = { items: Array.new(1 + rand(3), SCHEMA) }
          expect { validator.validate(schema) }.not_to raise_error
        end

        it 'raises an exception if the items value is an invalid schema' do
          schema = { items: 'not valid schema' }
          expect { validator.validate(schema) }.to raise_error(::Mongoff::Validator::Error)
        end

        it 'raises an exception if the items value is an array containing not valid schemas' do
          schema = { items: [validator, SCHEMA, validator] }
          expect { validator.validate(schema) }.to raise_error(::Mongoff::Validator::Error)
        end
      end

      context 'when validating keyword additionalItems' do

        it 'does not raise an exception if the additionalItems value is a valid schema' do
          schema = { additionalItems: SCHEMA }
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
          schema = { contains: SCHEMA }
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
          schema = { allOf: Array.new(1 + rand(3), SCHEMA) }
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
          schema = { anyOf: Array.new(1 + rand(3), SCHEMA) }
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
          schema = { oneOf: Array.new(1 + rand(3), SCHEMA) }
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
          schema = { not: SCHEMA }
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
        schema = { if: SCHEMA }
        expect { validator.validate(schema) }.not_to raise_error
      end

      it 'raises an exception if the if value is not a valid schema' do
        schema = { if: 'not valid schema' }
        expect { validator.validate(schema) }.to raise_error(::Mongoff::Validator::Error)
      end

      it 'does not raise an exception if the then value a valid schema' do
        schema = { then: SCHEMA }
        expect { validator.validate(schema) }.not_to raise_error
      end

      it 'raises an exception if the then value is not a valid schema' do
        schema = { then: 'not valid schema' }
        expect { validator.validate(schema) }.to raise_error(::Mongoff::Validator::Error)
      end

      it 'does not raise an exception if the else value a valid schema' do
        schema = { else: SCHEMA }
        expect { validator.validate(schema) }.not_to raise_error
      end

      it 'raises an exception if the else value is not a valid schema' do
        schema = { else: 'not valid schema' }
        expect { validator.validate(schema) }.to raise_error(::Mongoff::Validator::Error)
      end

      it 'does not raise an exception if the dependentSchema value is valid' do
        schema = {
          dependentSchema: {
            a: SCHEMA,
            b: SCHEMA
          }
        }
        expect { validator.validate(schema) }.not_to raise_error
      end

      it 'raises an exception if the dependentSchema value is not an object' do
        schema = {
          dependentSchema: 'not an object'
        }
        expect { validator.validate(schema) }.to raise_error(::Mongoff::Validator::Error)
      end

      it 'raises an exception if some dependentSchema value is not a valid schema' do
        schema = {
          dependentSchema: {
            a: SCHEMA,
            b: 'not valid schema'
          }
        }
        expect { validator.validate(schema) }.to raise_error(::Mongoff::Validator::Error)
      end
    end
  end
end
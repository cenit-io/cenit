require 'json-schema/schema/cenit_reader'

module Mongoid
  module Validatable
    class MongoffValidator < ActiveModel::EachValidator

      def validate_each(record, attribute, value)
        begin
          model = options[:model]
          JSON::Validator.validate!(model.schema, value, schema_reader: JSON::Schema::CenitReader.new(model.data_type))
        rescue Exception => ex
          record.errors.add(attribute, ex.message)
        end if value
      end
    end
  end
end
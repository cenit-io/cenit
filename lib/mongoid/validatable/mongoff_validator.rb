require 'json-schema/schema/cenit_reader'

module Mongoid
  module Validatable
    class MongoffValidator < ActiveModel::EachValidator

      def validate_each(record, attribute, value)
        begin
          model = options[:model]
          Mongoff::Validator.validate_instance(
            value,
            schema: model.schema,
            data_type: model.data_type
          )
        rescue Exception => ex
          record.errors.add(attribute, ex.message)
        end if value
      end
    end
  end
end
module Mongoid
  module Validatable

    class MongoffValidator < ActiveModel::EachValidator

      def validate_each(record, attribute, value)
        begin
          model = options[:model]
          JSON::Validator.validate!(model.data_type.merge_schema(model.schema), value)
        rescue Exception => ex
          record.errors.add(attribute, ex.message)
        end if value
      end
    end
  end
end
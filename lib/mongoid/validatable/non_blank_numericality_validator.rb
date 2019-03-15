module Mongoid
  module Validatable
    class NonBlankNumericalityValidator < ActiveModel::Validations::NumericalityValidator

      def validate_each(record, attribute, value)
        super if value.present?
      end
    end
  end
end
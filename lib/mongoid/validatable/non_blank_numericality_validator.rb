module Mongoid
  module Validatable

    class NonBlankNumericalityValidator < ActiveModel::Validations::NumericalityValidator

      def validate_each(record, attribute, value)
        super unless value.blank?
      end
    end

  end
end
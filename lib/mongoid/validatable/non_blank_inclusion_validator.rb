module Mongoid
  module Validatable
    class NonBlankInclusionValidator < ActiveModel::Validations::InclusionValidator

      def validate_each(record, attribute, value)
        super if value.present?
      end
    end
  end
end
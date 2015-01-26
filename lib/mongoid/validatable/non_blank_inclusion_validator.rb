module Mongoid
  module Validatable

    class NonBlankInclusionValidator < ActiveModel::Validations::InclusionValidator

      def validate_each(record, attribute, value)
        super unless value.blank?
      end
    end

  end
end
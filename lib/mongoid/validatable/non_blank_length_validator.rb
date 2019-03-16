module Mongoid
  module Validatable
    class NonBlankLengthValidator < LengthValidator

      def validate_each(record, attribute, value)
        super if value.present?
      end
    end
  end
end
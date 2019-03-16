module Mongoid
  module Validatable
    class NonBlankFormatValidator < FormatValidator

      def validate_each(record, attribute, value)
        super if value.present?
      end
    end
  end
end
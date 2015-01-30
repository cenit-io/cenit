module Mongoid
  module Validatable

    class NonBlankFormatValidator < FormatValidator

      def validate_each(record, attribute, value)
        super unless value.blank?
      end
    end

  end
end
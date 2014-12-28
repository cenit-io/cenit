module Mongoid
  module Validatable

    class NonBlankLengthValidator < LengthValidator

      def validate_each(record, attribute, value)
        super unless value.blank?
      end
    end

  end
end
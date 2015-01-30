module Mongoid
  module Validatable

    class NonBlankUniquenessValidator < UniquenessValidator

      def validate_each(record, attribute, value)
        super unless value.blank?
      end
    end

  end
end
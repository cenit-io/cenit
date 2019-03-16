module Mongoid
  module Validatable
    class NonBlankUniquenessValidator < UniquenessValidator

      def validate_each(record, attribute, value)
        super if value.present?
      end
    end
  end
end
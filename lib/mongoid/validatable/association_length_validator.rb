module Mongoid
  module Validatable
    class AssociationLengthValidator < LengthValidator

      def validate_each(record, attribute, value)
        if value = record.try(attribute)
          super
        end
      end
    end
  end
end
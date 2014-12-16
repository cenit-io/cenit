module Mongoid

  module Validatable
    class AssociationLengthValidator < LengthValidator

      def validate_each(record, attribute, value)
        value = record.send(attribute) rescue []
        super
      end
    end
  end

end
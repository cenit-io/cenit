module Mongoid
  module Validatable

    class AssociationLengthValidator < LengthValidator

      def validate_each(record, attribute, value)
        if value = record.send(attribute) rescue nil
          super
        end
      end
    end

  end
end
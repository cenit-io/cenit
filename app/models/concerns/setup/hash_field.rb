module Setup
  module HashField
    extend ActiveSupport::Concern

    included do
      before_save do
        check_before_save &&
          self.class.hash_fields.each do |field|
            if (value = attributes[field]).is_a?(Hash)
              attributes[field] = value = value.to_json
            end
            if (changed_value = changed_attributes[field]) &&
               (changed_value.is_a?(String) || (changed_value = changed_value.to_json)) &&
               value == changed_value
              changed_attributes.delete(field)
            else
              changed_attributes[field] = changed_value
            end
          end
        abort_if_has_errors
      end
    end

    def check_before_save
      errors.blank?
    end

    def hash_attribute_read(name, value)
      value
    end

    def read_raw_attribute(name)
      value = super
      name = name.to_s
      if self.class.hash_fields.include?(name)
        value =
          if value.is_a?(String)
            value =
              begin
                hash_attribute_read(name, JSON.parse(value))
              rescue Exception
                value
              end
            attributes[name] = value
            attributes[name]
          else
            hash_attribute_read(name, value)
          end
      end
      value
    end

    module ClassMethods
      def local_hash_fields
        @hash_fields ||= []
      end

      def hash_fields
        if superclass < HashField
          superclass.hash_fields
        else
          []
        end + local_hash_fields
      end

      def hash_field(*field_names)
        field_names = field_names.collect(&:to_s)
        field_names.reject!(&:blank?)

        field_names.each do |field_name|
          field field_name, default: {}
          local_hash_fields << field_name
        end
      end
    end
  end
end

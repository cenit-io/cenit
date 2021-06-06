module Setup
  module ReqRejValidator
    extend ActiveSupport::Concern

    def reject_message(_field = nil)
      'is not allowed'
    end

    def rejects(*fields)
      r = false
      fields.each do |field|
        next unless send(field).present?
        changed =
          if (relation = reflect_on_association(field))
            send(relation.foreign_key_check)
          else
            changed_attributes.key?(field.to_s)
          end
        send("#{field}=", nil)
        next unless changed
        errors.add(field, reject_message(field))
        r = true
      end
      r
    end

    def requires(*fields)
      r = false
      fields.each do |field|
        unless send(field).present?
          r = true
          errors.add(field, "can't be blank")
        end
      end
      r
    end
  end
end

module Setup
  module ReqRejValidator
    extend ActiveSupport::Concern

    def reject_message(field=nil)
      'is not allowed'
    end

    def rejects(*fields)
      r = false
      fields.each do |field|
        if send(field).present?
          changed =
            if (relation = reflect_on_association(field))
              send(relation.foreign_key_check)
            else
              changed_attributes.key?(field.to_s)
            end
          send("#{field}=", nil)
          if changed
            errors.add(field, reject_message(field))
            r = true
          end
        end
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

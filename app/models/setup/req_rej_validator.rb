module Setup
  class ReqRejValidator

    def reject_message(field=nil)
      'is not allowed'
    end

    def rejects(*fields)
      r = false
      fields.each do |field|
        if send(field).present?
          errors.add(field, reject_message)
          send("#{field}=", nil)
          r = true
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

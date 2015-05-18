module Setup
  module CommonParser

    def create_from_edi(data, options={})
      save_record(new_from_edi(data, options))
    end

    def create_from_json(data, options={})
      save_record(new_from_json(data, options))
    end

    def create_from_xml(data, options={})
      save_record(new_from_xml(data, options))
    end

    def create_from_edi!(data, options={})
      unless (record = create_from_edi(data, options)).errors.blank?
        raise Exception.new(record.errors.full_messages.to_sentence)
      end
      record
    end

    def create_from_json!(data, options={})
      unless (record = create_from_json(data, options)).errors.blank?
        raise Exception.new(record.errors.full_messages.to_sentence)
      end
      record
    end

    def create_from_xml!(data, options={})
      unless (record = create_from_xml(data, options)).errors.blank?
        raise Exception.new(record.errors.full_messages.to_sentence)
      end
      record
    end

    private

    def save_record(record)
      Cenit::Utility.save(record)
      record
    end
  end
end
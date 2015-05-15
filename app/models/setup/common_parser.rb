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
      save_record!(new_from_edi(data, options))
    end

    def create_from_json!(data, options={})
      save_record!(new_from_json(data, options))
    end

    def create_from_xml!(data, options={})
      save_record!(new_from_xml(data, options))
    end

    private

    def save_record(record)
      Cenit::Utility.save(record)
      record
    end

    def save_record!(record)
      unless save_record(record).errors.blank?
        raise Exception.new(record.errors.full_messages.to_sentence)
      end
      record
    end
  end
end
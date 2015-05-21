module Setup
  module CommonParser
    
    def create_from(data, options = {})
      if formatted_data = JSON.parse(data) rescue nil
       create_from_json(formatted_data, options)
      elsif formatted_data = Nokogiri::XML(data) rescue nil
        create_from_xml(formatted_data, options)
      else
        create_from_edi(formatted_data, options)
      end
    end

    def create_from_edi(data, options = {})
      save_record(new_from_edi(data, options), options)
    end

    def create_from_json(data, options = {})
      save_record(new_from_json(data, options), options)
    end

    def create_from_xml(data, options = {})
      save_record(new_from_xml(data, options), options)
    end

    def create_from!(data, options = {})
      unless (record = create_from(data, options)).errors.blank?
        raise Exception.new(record.errors.full_messages.to_sentence)
      end
      record
    end

    def create_from_edi!(data, options = {})
      unless (record = create_from_edi(data, options)).errors.blank?
        raise Exception.new(record.errors.full_messages.to_sentence)
      end
      record
    end

    def create_from_json!(data, options = {})
      unless (record = create_from_json(data, options)).errors.blank?
        raise Exception.new(record.errors.full_messages.to_sentence)
      end
      record
    end

    def create_from_xml!(data, options = {})
      unless (record = create_from_xml(data, options)).errors.blank?
        raise Exception.new(record.errors.full_messages.to_sentence)
      end
      record
    end

    private

    def save_record(record, options)
      Cenit::Utility.save(record, options)
      record
    end
  end
end
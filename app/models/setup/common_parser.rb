module Setup
  module CommonParser
    def regist_creation_listener(listener)
      (@creation_listeners ||= []) << listener
    end

    def unregist_creation_listener(listener)
      @creation_listeners.delete(listener) if @creation_listeners
    end

    def new_from(data, options = {})
      json_data = (data.is_a?(Hash) && data) ||
        begin
          JSON.parse(data)
        rescue
          nil
        end
      if json_data
        new_from_json(json_data, options)
      else
        xml_data =
          begin
            Nokogiri::XML(data)
          rescue
            nil
          end
        if xml_data
          new_from_xml(Nokogiri::XML(data))
        else
          new_from_edi(data, options)
        end
      end
    end

    def create_from(data, options = {})
      save_record(new_from(data, options), options)
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
        fail record.errors.full_messages.to_sentence
      end
      record
    end

    def create_from_edi!(data, options = {})
      unless (record = create_from_edi(data, options)).errors.blank?
        fail record.errors.full_messages.to_sentence
      end
      record
    end

    def create_from_json!(data, options = {})
      unless (record = create_from_json(data, options)).errors.blank?
        fail record.errors.full_messages.to_sentence
      end
      record
    end

    def create_from_xml!(data, options = {})
      unless (record = create_from_xml(data, options)).errors.blank?
        fail record.errors.full_messages.to_sentence
      end
      record
    end

    EDI_PARSED_RECORD = ->(r) { r.instance_variable_get(:@_edi_parsed) }

    private

    def save_record(record, options)
      create = true
      @creation_listeners.each { |listener| create &&= listener.try(:before_create, record) } if @creation_listeners
      if create
        Cenit::Utility.save(record, options.merge(bind_references: { if: EDI_PARSED_RECORD }))
        @creation_listeners.each { |listener| listener.try(:after_create, record) } if @creation_listeners
      end
      record
    end
  end
end

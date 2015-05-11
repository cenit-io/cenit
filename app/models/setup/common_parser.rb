module Setup
  module CommonParser

    def create_from_edi(data, options={})
      save_record!(new_from_edi(data, options))
    end

    def create_from_json(data, options={})
      save_record!(new_from_json(data, options))
    end

    def create_from_xml(data, options={})
      save_record!(new_from_xml(data, options))
    end

    private

    def save_record!(record)
      unless Cenit::Utility.save(record)
        raise Exception.new("Record #{record} is not valid")
      end
    end
  end
end
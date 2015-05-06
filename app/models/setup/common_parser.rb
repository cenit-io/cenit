module Setup
  module CommonParser

    def create_from_edi(data, options={})
      new_from_edi(data, options).save!
    end

    def create_from_json(data, options={})
      new_from_json(data, options).save!
    end

    def create_from_xml(data, options={})
      new_from_xml(data, options).save!
    end
  end
end
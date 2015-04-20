module Setup
  module FormatParser

    def new_from_edi(data, options={})
      Edi::Parser.parse_edi(self, data, options)
    end

    def create_from_edi(data, options={})
      new_from_edi(data, options).save!
    end

    def new_from_json(data, options={})
      Edi::Parser.parse_json(self, data, options)
    end

    def create_from_json(data, options={})
      new_from_json(data, options).save!
    end

    def new_from_xml(data, options={})
      Edi::Parser.parse_xml(self, data, options)
    end

    def create_from_xml(data, options={})
      new_from_xml(data, options).save!
    end

  end
end
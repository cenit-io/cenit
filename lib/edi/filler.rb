module Edi
  module Filler

    def from_edi(data, options={})
      Edi::Parser.parse_edi(self.class.data_type, data, options, self)
    end

    def from_json(data, options={})
      Edi::Parser.parse_json(self.class.data_type, data, options, self)
    end

    def from_xml(data, options={})
      Edi::Parser.parse_xml(self.class.data_type, data, options, self)
    end
  end
end
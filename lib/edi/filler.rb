module Edi
  module Filler

    def from_edi(data, options={})
      Edi::Parser.parse_edi(self.orm_model.data_type, data, options, self)
      self
    end

    def from_json(data, options={})
      Edi::Parser.parse_json(self.orm_model.data_type, data, options, self)
      self
    end

    def from_xml(data, options={})
      Edi::Parser.parse_xml(self.orm_model.data_type, data, options, self)
      self
    end
  end
end
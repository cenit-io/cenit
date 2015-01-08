module Edi
  module Filler

    def from_edi(data, options={})
      Edi::Parser.parse_edi(data_type, data, options, self)
    end

    def from_json(data, options={})
      Edi::Parser.parse_json(data_type, data, options, self)
    end

    def from_xml(data, options={})
      Edi::Parser.parse_xml(data_type, data, options, self)
    end
  end
end
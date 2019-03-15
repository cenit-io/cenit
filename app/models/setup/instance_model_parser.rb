module Setup
  module InstanceModelParser
    include CommonParser

    def new_from_edi(data, options={})
      Edi::Parser.parse_edi(data_type, data, options)
    end

    def new_from_json(data, options={})
      Edi::Parser.parse_json(data_type, data, options, nil, self)
    end

    def new_from_xml(data, options={})
      Edi::Parser.parse_xml(data_type, data, options)
    end

  end
end

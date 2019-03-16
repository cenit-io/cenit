module Setup
  module DataTypeParser
    include CommonParser

    def new_from_edi(data, options = {})
      post_process(Edi::Parser.parse_edi(parser_data_type, data, options))
    end

    def new_from_json(data, options = {})
      post_process(Edi::Parser.parse_json(parser_data_type, data, options, nil, records_model))
    end

    def new_from_xml(data, options = {})
      if (record = Edi::Parser.parse_xml(parser_data_type, data, options))
        post_process(record)
      else
        fail "XML data does not match #{custom_title} schema"
      end
    end

    def parser_data_type
      self
    end

    private

    def post_process(record)
      Cenit::Utility.bind_references(record, if: EDI_PARSED_RECORD)
      record
    end
  end
end

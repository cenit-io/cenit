module Setup
  module DataTypeParser
    include CommonParser

    def new_from_edi(data, options={})
      post_process(Edi::Parser.parse_edi(self, data, options))
    end


    def new_from_json(data, options={})
      post_process(Edi::Parser.parse_json(self, data, options, nil, records_model))
    end


    def new_from_xml(data, options={})
      post_process(Edi::Parser.parse_xml(self, data, options))
    end

    private

    def post_process(record)
      Cenit::Utility.bind_references(record, if: EDI_PARSED_RECORD)
      record
    end

  end
end
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

    def instance_pending_references(*fields)
      return unless (refs = instance_variable_get(:@_references))
      fields.each do |f|
        next unless (ref = refs[f.name.to_s])
        self[f.name] = ref[:model].new_from_json(ref[:criteria])
      end
    end
  end
end
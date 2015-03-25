module Mongoff
  class Record
    include Edi::Filler
    include Edi::Formatter

    attr_reader :orm_model
    attr_reader :document

    def initialize(model, document = BSON::Document.new)
      @orm_model = model
      @document = document
      @fields = {}
    end

    def schema
      @schema ||= orm_model.data_type.merged_schema
    end

    def is_a?(model)
      if model.is_a?(Mongoff::Model)
        orm_model == model
      else
        super
      end
    end

    def errors
      @errors ||= ActiveModel::Errors.new(self)
    end

    def valid?
      #TODO Schema validation
      errors.blank?
    end

    def save(options = {})
      if errors.blank?
        errors.add(:base, "Save operation not supported on not loaded data type #{orm_model.data_type.title}")
      end
      false
    end

    def method_missing(symbol, *args)
      if symbol.to_s.end_with?('=')
        symbol = symbol.to_s.chop.to_sym
        value = args[0]
        @fields.delete(symbol)
        if value.nil?
          document.delete(symbol)
        elsif value.is_a?(Record)
          @fields[symbol] = value
          document[symbol] = value.document
        else
          document[symbol] = value
        end
      else
        if (value = (@fields[symbol] || document[symbol])).is_a?(BSON::Document)
          @fields[symbol] = Record.new(orm_model.property_model(symbol), value)
        elsif value.is_a?(::Array)
          @fields[symbol] = RecordArray.new(orm_model.property_model(symbol), value)
        else
          value
        end
      end
    end

  end
end
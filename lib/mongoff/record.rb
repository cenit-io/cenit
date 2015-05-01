module Mongoff
  class Record
    include Edi::Filler
    include Edi::Formatter

    attr_reader :orm_model
    attr_reader :document

    def initialize(model, document = nil, new_record = true)
      @orm_model = model
      @document = document || BSON::Document.new
      @fields = {}
      @document[:_id] ||= BSON::ObjectId.new unless model.property_model(:_id)
      @new_record = new_record || false
    end

    def attributes
      update_ids
      @document
    end

    def id
      self[:_id]
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

    def new_record?
      @new_record
    end

    def save(options = {})
      if new_record?
        orm_model.collection.insert(attributes)
      else
        orm_model.collection.find(_id: id).update('$set' => attributes)
      end
      true
    end

    def [](field)
      attribute_key = attribute_key(field, property_model = orm_model.property_model(field))
      if (value = (@fields[field] || document[attribute_key])).is_a?(BSON::Document) && property_model
        @fields[field] = Record.new(property_model, value)
      elsif value.is_a?(::Array) && property_model
        @fields[field] ||= RecordArray.new(property_model, value, field != attribute_key)
      else
        value
      end
    end

    def []=(field, value)
      @fields.delete(field)
      attribute_key = attribute_key(field, property_model = orm_model.property_model(field))
      if value.nil?
        document.delete(attribute_key)
      elsif value.is_a?(Record) || value.class.respond_to?(:data_type)
        @fields[field] = value
        document[attribute_key] = value.attributes if attribute_key == field
      elsif value.is_a?(Enumerable)
        document[attribute_key] = attr_array = []
        if property_model
          @fields[field] = field_array = RecordArray.new(property_model, attr_array, attribute_key != field)
          value.each do |v|
            field_array << v
            attr_array << (attribute_key == field ? v.attributes : v.id)
          end
        else
          value.each do |v|
            raise Exception.new("invalid value #{v}") unless Cenit::Utility.json_object?(v, recursive: true)
            attr_array << v
          end
        end unless value.empty?
      else
        document[field] = value
      end
    end

    def method_missing(symbol, *args)
      if symbol.to_s.end_with?('=')
        self[symbol.to_s.chop.to_sym] = args[0]
      elsif args.blank?
        self[symbol]
      else
        super
      end
    end

    protected

    def attribute_key(field, property_model = nil)
      if (property_model || orm_model.property_model(field)) && (schema = orm_model.property_schema(field))['referenced']
        return ("#{field}_id" + ('s' if schema['type'] == 'array').to_s).to_sym
      end
      field
    end

    def update_ids
      @fields.each do |field, value|
        unless @document[field]
          attribute_key = attribute_key(field)
          if value.is_a?(RecordArray)
            @document[attribute_key] = array = []
            value.each do |v|
              v.update_ids if v.is_a?(Record)
              array << v.id
            end
          else
            value.update_ids if value.is_a?(Record)
            @document[attribute_key] = value.id
          end
        end
      end
    end
  end
end
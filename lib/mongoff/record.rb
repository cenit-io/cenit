module Mongoff
  class Record
    include Edi::Filler
    include Edi::Formatter
    include RecordsMethods
    include ActiveModel::ForbiddenAttributesProtection

    attr_reader :orm_model
    attr_reader :document
    attr_reader :fields

    def initialize(model, attributes = nil, new_record = true)
      @orm_model = model
      @document = BSON::Document.new
      @document[:_id] ||= BSON::ObjectId.new unless model.property_schema(:_id)
      @fields = {}
      @new_record = new_record || false
      model.simple_properties_schemas.each do |property, schema| #TODO Defaults for non simple properties
        if @document[property].nil? && value = schema['default']
          self[property] = value
        end
      end
      assign_attributes(attributes)
      Cenit::Utility.for_each_node_starting_at(self) { |record| record.instance_variable_set(:@new_record, false) } unless @new_record
    end

    def attributes
      prepare_attributes
      document
    end

    def assign_attributes(attrs = nil)
      attrs ||= {}
      if !attrs.empty?
        attrs = sanitize_for_mass_assignment(attrs)
        attrs.each_pair do |key, value|
          self[key] = value
        end
      end
      yield self if block_given?
    end

    def id
      self[:_id]
    end

    def is_a?(model)
      if model.is_a?(Mongoff::Model)
        orm_model.eql?(model)
      else
        super
      end
    end

    def errors
      @errors ||= ActiveModel::Errors.new(self)
    end

    def new_record?
      @new_record
    end

    def persisted?
      !new_record? && !destroyed?
    end

    def destroyed?
      @destroyed ||= false
    end

    def save!(options = {})
      raise Exception.new('Invalid data') unless save(options)
    end

    def save(options = {})
      errors.clear
      if destroyed?
        errors.add(:base, 'Destroyed record can not be saved')
        return false
      end
      orm_model.fully_validate_against_schema(attributes).each do |error|
        errors.add(:base, error[:message])
      end
      begin
        Model.before_save.call(self)
        if new_record?
          orm_model.collection.insert(attributes)
          @new_record = false
        else
          query = orm_model.collection.find(_id: id)
          set = attributes
          unset = {}
          if doc = query.first
            doc.keys.each { |key| unset[key] = '' unless set.has_key?(key) }
          end
          update = {'$set' => set}
          if unset.present?
            update['$unset'] = unset
          end
          query.update(update)
        end
        Model.after_save.call(self)
      rescue Exception => ex
        errors.add(:base, ex.message)
      end if errors.blank?
      errors.blank?
    end

    def destroy
      begin
        orm_model.where(id: id).remove
      rescue
      end
      @destroyed = true
    end

    def [](field)
      attribute_key = orm_model.attribute_key(field, model: property_model = orm_model.property_model(field))
      if (value = (@fields[field] || document[attribute_key])).is_a?(BSON::Document) && property_model && property_model.modelable?
        @fields[field] = Record.new(property_model, value)
      elsif property_model && property_model.modelable? && orm_model.property_schema(field)['type'] == 'array'
        @fields[field] ||= RecordArray.new(property_model, value, field != attribute_key)
      else
        value
      end
    end

    def []=(field, value)
      field = :_id if %w(id _id).include?(field.to_s)
      if !orm_model.property?(field) && association = nested_attributes_association(field)
        fail "invalid attributes format #{value}" unless value.is_a?(Hash)
        associates = {}
        if association.many?
          value = value.values
          self[association.name]
        else
          value = [value]
          [self[association.name]]
        end.each do |associated|
          associates[associated.to_hash(only: :id)['id']] = associated
        end
        new_associates = []
        value.each do |attributes|
          unless (attributes.delete('_destroy')).present?
            unless associated = associates[attributes['id'] || attributes['_id']]
              associated = association.klass.new
            end
            associated.assign_attributes(attributes)
            new_associates << associated
          end
        end
        self[association.name] = new_associates =
          if association.many?
            new_associates
          elsif new_associates.present?
            new_associates[0]
          else
            nil
          end
        return new_associates
      end
      attribute_key = orm_model.attribute_key(field, field_metadata = {})
      field_metadata_2 = {}
      attribute_assigning = !orm_model.property?(attribute_key) && attribute_key == field &&
        (field = orm_model.properties.detect { |property| orm_model.attribute_key(property, field_metadata_2 = {}) == attribute_key }).present?
      field =
        if field
          field_metadata = field_metadata_2 if field_metadata.blank?
          field
        else
          attribute_key
        end.to_sym
      @fields.delete(field)
      property_model = field_metadata[:model]
      property_schema = field_metadata[:schema] || orm_model.property_schema(field)
      if value.nil?
        @fields.delete(field)
        document.delete(attribute_key)
      elsif value.is_a?(Record) || value.class.respond_to?(:data_type)
        @fields[field] = value
        document[attribute_key] = value.attributes if attribute_key == field
      elsif !value.is_a?(Hash) && value.is_a?(Enumerable)
        document[attribute_key] = attr_array = []
        if !attribute_assigning && property_model && property_model.modelable?
          @fields[field] = field_array = RecordArray.new(property_model, attr_array, attribute_key != field.to_s)
          value.each do |v|
            field_array << v
          end
        else
          if property_model && property_model.modelable?
            value = value.collect { |v| property_model.mongo_value(v, :id) }.select(&:present?)
          end
          value.each do |v|
            fail "invalid value #{v}" unless Cenit::Utility.json_object?(v, recursive: true)
            attr_array << v
          end
        end unless value.empty?
      else
        document[field] = orm_model.mongo_value(value, property_schema.present? ? property_schema : field)
      end
    end

    def respond_to?(*args)
      super ||
        begin
          method = args.first.to_s
          property = (assigning = method.end_with?('=')) ? method.chop : method
          orm_model.property?(property) ||
            orm_model.data_type.records_methods.any? { |alg| alg.name == method } ||
            nested_attributes_association(property).present?
        end
    end

    def method_missing(symbol, *args)
      if method = orm_model.data_type.records_methods.detect { |alg| alg.name == symbol.to_s }
        args.unshift(self)
        method.reload
        method.run(args)
      elsif symbol.to_s.end_with?('=')
        self[symbol.to_s.chop.to_sym] = args[0]
      elsif args.blank?
        self[symbol]
      else
        super
      end
    end

    def nested_attributes_association(property)
      property = property.to_s
      if property.end_with?('_attributes')
        property = property.to(property.rindex('_') - 1)
        orm_model.associations[property.to_sym]
      else
        nil
      end
    end

    def to_s
      orm_model.to_s + '#' + id.to_s
    end

    def eql?(other)
      other.is_a?(Mongoff::Record) && other.orm_model.eql?(orm_model) && other.id.eql?(id)
    end

    protected

    def prepare_attributes
      document[:_type] = orm_model.to_s if orm_model.reflectable?
      @fields.each do |field, value|
        nested = (association = orm_model.associations[field]) && association.nested?
        if nested || document[field].nil?
          nested = (association = orm_model.associations[field]) && association.nested?
          attribute_key = orm_model.attribute_key(field)
          if value.is_a?(RecordArray)
            document[attribute_key] = value.collect { |v| nested ? v.attributes : v.id }
          else
            document[attribute_key] = nested ? value.attributes : value.id
          end
        end
      end
    end
  end
end
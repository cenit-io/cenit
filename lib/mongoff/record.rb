module Mongoff
  class Record
    include Savable
    include Destroyable
    include Edi::Filler
    include Edi::Formatter
    include RecordsMethods
    include ActiveModel::ForbiddenAttributesProtection
    include Cenit::Liquidfier

    attr_reader :orm_model
    attr_reader :document
    attr_reader :fields

    def initialize(model, attributes = nil, new_record = true)
      @orm_model = model
      @document = BSON::Document.new
      unless (id_schema = model.property_schema(:_id)) && id_schema.key?('type')
        @document[:_id] ||= BSON::ObjectId.new
      end
      @fields = {}
      @new_record = new_record || false
      model.properties_schemas.each do |property, schema|
        if @document[property].nil? && !(value = schema['default']).nil?
          self[property] = value
        end
      end
      assign_attributes(attributes)
      Cenit::Utility.for_each_node_starting_at(self) { |record| record.instance_variable_set(:@new_record, false) } unless @new_record
      @changed = false
    end

    def attributes
      prepare_attributes
      document
    end

    def assign_attributes(attrs = nil)
      attrs ||= {}
      unless attrs.empty?
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

    def becomes(klass)
      became = klass.new(attributes)
      became.id = id
      became.instance_variable_set(:@errors, ActiveModel::Errors.new(became))
      became.errors.instance_variable_set(:@messages, errors.instance_variable_get(:@messages))
      became.instance_variable_set(:@new_record, new_record?)
      became.instance_variable_set(:@destroyed, destroyed?)
      became._type = klass.to_s
      became
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

    def validate
      unless @vailidated
        errors.clear
        orm_model.fully_validate_against_schema(attributes).each do |error|
          errors.add(:base, error[:message])
        end
        @validated = true
      end
    end

    def valid?
      validate
      errors.blank?
    end

    def [](field)
      field = field.to_sym
      attribute_key = orm_model.attribute_key(field, model: property_model = orm_model.property_model(field))
      value = @fields[field] || document[attribute_key]
      if property_model && property_model.modelable?
        @fields[field] ||=
          if (association = orm_model.associations[field.to_s]).many?
            RecordArray.new(property_model, value, association.referenced?)
          else
            if association.referenced?
              value && property_model.find(value) rescue nil
            elsif value
              Record.new(property_model, value)
            else
              nil
            end
          end
      else
        value
      end
    end

    #TODO Implements ActiveModel changes pattern
    def changed?
      @changed || @fields.values.any? { |value| value && value.respond_to?(:changed?) && value.changed? }
    end

    def []=(field, value)
      field = field.to_sym
      @changed = true
      @validated = false
      field = :_id if %w(id _id).include?(field.to_s)
      if !orm_model.property?(field) && (association = nested_attributes_association(field))
        fail "invalid attributes format #{value}" unless value.is_a?(Hash)
        associates = {}
        if association.many?
          value = value.values
          self[association.name]
        else
          value = [value]
          [self[association.name]]
        end.each do |associated|
          associates[associated.to_hash(only: :id)['id']] = associated if associated
        end
        new_associates = []
        value.each do |attributes|
          unless attributes.delete('_destroy').to_b
            unless (associated = associates[attributes['id'] || attributes['_id']])
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
      property_model = field_metadata[:model] || orm_model.property_model(field)
      property_schema = field_metadata[:schema] || orm_model.property_schema(field)
      if value.nil?
        @fields.delete(field)
        document.delete(attribute_key.to_s)
        nil
      elsif value.is_a?(Record) || value.class.respond_to?(:data_type)
        @fields[field] = value
        document[attribute_key] = attribute_key == field ? value.attributes : value.id
      elsif !value.is_a?(Hash) && value.is_a?(Enumerable)
        attr_array = []
        if !attribute_assigning && property_model && property_model.modelable?
          @fields[field] = field_array = RecordArray.new(property_model, attr_array, attribute_key != field.to_s)
          value.each do |v|
            field_array << v
          end
          field_array
        else
          if property_model && property_model.modelable?
            mongo_value = []
            value.each do |v|
              property_model.mongo_value(v, :id) do |mongo_v|
                mongo_value << mongo_v
              end
            end
            value = mongo_value
          end
          value.each do |v|
            fail "invalid value #{v}" unless Cenit::Utility.json_object?(v, recursive: true)
            attr_array << v
          end
        end unless value.empty?
        document[attribute_key] = attr_array
      else
        document[attribute_key ||= field] = value = orm_model.mongo_value(value, field, property_schema)
        document.delete(attribute_key.to_s) if value.nil? && !orm_model.requires?(field)
        value
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

    def send(*args)
      name = args[0].to_s
      property_name = (assigning = name.end_with?('=')) ? name.chop : name
      if (method = orm_model.data_type.records_methods.detect { |alg| alg.name == name })
        args = args.dup
        args[0] = self
        method.reload
        method.run(args)
      elsif orm_model.property?(property_name) && (args.length == (assigning ? 2 : 1))
        if assigning
          self[property_name] = args[1]
        else
          self[property_name]
        end
      else
        super
      end
    end

    def method_missing(symbol, *args)
      if (method = orm_model.data_type.records_methods.detect { |alg| alg.name == symbol.to_s })
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
      if orm_model
        case (template = orm_model.label_template)
        when String
          template
        when Liquid::Template
          begin
            template.render document
          rescue Exception => ex
            ex.message
          end
        else
          "#{orm_model.label} ##{id}"
        end
      else
        super
      end
    end

    def eql?(other)
      other.is_a?(Mongoff::Record) && other.orm_model.eql?(orm_model) && other.id.eql?(id)
    end

    def _reload
      {}.merge(orm_model.collection.find(_id: _id).read(mode: :primary).first || {})
    end

    def reflect_on_all_associations(*macros)
      self.class.reflect_on_all_associations(*macros)
    end

    def reflect_on_association(name)
      self.class.reflect_on_association(name)
    end

    protected

    def prepare_attributes
      document[:_type] = orm_model.to_s if orm_model.reflectable?
      @fields.each do |field, value|
        nested = (association = orm_model.associations[field]) && association.nested?
        if nested || document[field].nil?
          attribute_key = orm_model.attribute_key(field)
          if value.is_a?(RecordArray)
            document[attribute_key] = value.collect { |v| nested ? v.attributes : v.id }
          else
            document[attribute_key] = nested ? value.attributes : value.id unless value.nil?
          end
        end
      end
    end

    def before_save_callbacks
      success = true
      if (data_type = (model = orm_model).data_type).records_model == model
        data_type.before_save_callbacks.each do |callback|
          next unless success
          success &&=
            begin
              callback.run(self).present?
            rescue Exception => ex
              obj_msg =
                if new_record?
                  'creating record'
                else
                  "updating record with ID '#{id}'"
                end
              Setup::SystemNotification.create(message: "Error #{obj_msg} with type ' #{orm_model.data_type.custom_title}', running before save callback '#{callback.custom_title}': #{ex.message}")
              false
            end
        end
      end
      success
    end

    def run_callbacks_and
      begin
        if Model.before_save.call(self) && before_save_callbacks
          yield if block_given?
          Model.after_save.call(self)
        end
      rescue Exception => ex
        errors.add(:base, ex.message)
      end
      errors.blank?
    end
  end
end

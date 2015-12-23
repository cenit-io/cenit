module Setup
  class DataTypeOptimizer

    def initialize
      @libraries = Hash.new { |h, k| h[k] = {} }
    end

    def regist_data_types(data_types)
      data_types = [data_types] unless data_types.is_a?(Enumerable)
      if data_type = data_types.first
        hash = @libraries[data_type.library.id]
        data_types.each do |data_type|
          hash[data_type.name] = data_type unless hash.has_key?(data_type.name)
        end
      end
    end

    def find_data_type(ref, library_id = self.library_id)
      unless data_type = (hash = @libraries[library_id])[ref]
        if data_type = Setup::DataType.where(name: ref, library_id: library_id).first
          hash[ref] = data_type
        elsif (ref = ref.to_s).start_with?('Dt')
          data_type = Setup::DataType.where(id: ref.from(2)).first
        end
      end
      data_type
    end

    def optimize
      data_types = @libraries.values.collect { |hash| hash.values.to_a }.flatten
      while data_type = data_types.shift
        segments = {}
        refs = Set.new
        schema = data_type.merged_schema(ref_collector: refs)
        if schema['type'] == 'object' && properties = schema['properties']
          properties = data_type.merge_schema(properties, ref_collector: refs)
          properties.each do |property_name, property_schema|
            property_segment = nil
            property_schema = data_type.merge_schema(property_schema, ref_collector: refs)
            if property_schema['type'] == 'array' && items = property_schema['items']
              property_schema['items'] = items = data_type.merge_schema(items, ref_collector: refs)
              if (edi_opts = items['edi']) && edi_opts.has_key?('segment')
                property_segment = edi_opts['segment']
              end
            end
            properties[property_name] = property_schema
            if (edi_opts = property_schema['edi']) && edi_opts.has_key?('segment')
              property_segment = edi_opts['segment']
            end
            segments[property_segment] = property_name if property_segment
          end
          schema['properties'] = properties
        end
        #TODO inject refs dependencies
        (schema['edi'] ||= {})['segments'] = segments
        data_type.schema = schema
      end
    end

    def save_data_types
      errors = []
      optimize
      new_attributes = []
      valid = true
      @libraries.each_value do |data_types_hash|
        data_types_hash.each_value do |data_type|
          dt_valid = true
          if (dt_valid = data_type.valid?(:create)) && valid
            if data_type.new_record?
              data_type.instance_variable_set(:@dynamically_created, true)
              data_type.instance_variable_set(:@new_record, false)
              new_attributes << data_type.attributes
            else
              #TODO ?
            end
          else
            errors += data_type.errors.full_messages.collect { |msg| "On data type #{data_type.name}: #{msg}" }
            valid = false unless dt_valid
          end
        end
      end
      if valid && new_attributes.present?
        Setup::SchemaDataType.collection.insert_many(new_attributes)
      end
      errors
    end

    class << self

      def optimizer
        Thread.current[:optimizer]
      end

      def new_optimizer
        Thread.current[:optimizer] = Setup::DataTypeOptimizer.new
      end

      def save_data_types
        if o = optimizer
          o.save_data_types
        end
      end
    end
  end
end
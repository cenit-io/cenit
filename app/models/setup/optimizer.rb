module Setup
  class Optimizer

    def initialize
      @nss = Hash.new { |h, k| h[k] = {} }
    end

    def regist_data_types(data_types)
      data_types = [data_types] unless data_types.is_a?(Enumerable)
      data_types.each do |dt|
        next unless dt.is_a?(Setup::DataType)
        @nss[dt.namespace][dt.name] = dt
      end
    end

    def find_data_type(ref, ns = self.namespace)
      if ref.is_a?(Hash)
        ns = ref['namespace'].to_s
        ref = ref['name']
      end
      unless (data_type = (ns_hash = @nss[ns])[ref])
        if (data_type = Setup::DataType.where(namespace: ns, name: ref).first)
          ns_hash[ref] = data_type
        elsif (ref = ref.to_s).start_with?('Dt')
          data_type = Setup::DataType.where(id: ref.from(2)).first
        end
      end
      data_type
    end

    def optimize
      data_types = @nss.values.collect { |ns_hash| ns_hash.values.to_a }.flatten
      while (data_type = data_types.shift)
        segments = {}
        refs = Set.new
        schema = data_type.merged_schema(ref_collector: refs)
        if schema['type'] == 'object' && (properties = schema['properties'])
          properties = data_type.merge_schema(properties, ref_collector: refs)
          properties.each do |property_name, property_schema|
            property_segment = nil
            property_schema = data_type.merge_schema(property_schema, ref_collector: refs)
            if property_schema['type'] == 'array' && (items = property_schema['items'])
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
      @nss.each_value do |data_types_hash|
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
        Setup::JsonDataType.collection.insert_many(new_attributes)
      end
      errors
    end

    def registered_nss
      @registered_nss ||= Set.new
    end

    def regist_ns(ns)
      registered_nss << ns
    end

    def save_namespaces
      if registered_nss.present?
        existing_nss = Setup::Namespace.any_in(name: registered_nss.to_a).distinct(:name)
        registered_nss.each { |ns| Setup::Namespace.create(name: ns) unless existing_nss.include?(ns) }
      end
    end

    class << self

      def optimizer
        Thread.current[thread_key]
      end

      def instance
        Thread.current[thread_key] ||= Setup::Optimizer.new
      end

      def thread_key
        "[cenit]#{to_s}"
      end

      delegate(*Setup::Optimizer.instance_methods(false), to: :instance)
    end

  end
end

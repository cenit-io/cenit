module Mongoff
  module GridFs
    module FileFormatter

      def to_hash(options = {})
        if orm_model.data_type.records_methods.any? { |alg| alg.name = 'to_hash' }
          return method_missing(:to_hash, options)
        end
        data = self.data
        data_type = orm_model.data_type
        options = options.merge(schema_data_type: data_type.schema_data_type)
        unless (format_validator = data_type.format_validator).nil? || format_validator.data_format == :json
          ignore = (options[:ignore] || [])
          ignore = [ignore] unless ignore.is_a?(Enumerable)
          ignore = ignore.select { |p| p.is_a?(Symbol) || p.is_a?(String) }.collect(&:to_sym)
          options[:ignore] = ignore
          data = format_validator.format_to(:json, data, options)
        end
        hash = JSON.parse(data)
        hash = {data_type.name.downcase => hash} if options[:include_root]
        hash
      end

      def to_json(options = {})
        if orm_model.data_type.records_methods.any? { |alg| alg.name == 'to_json' }
          return method_missing(:to_json, options)
        end
        data = self.data
        data_type = orm_model.data_type
        options = options.merge(schema_data_type: data_type.schema_data_type)
        unless (format_validator = data_type.format_validator).nil? || format_validator.data_format == :json
          ignore = (options[:ignore] || [])
          ignore = [ignore] unless ignore.is_a?(Enumerable)
          ignore = ignore.select { |p| p.is_a?(Symbol) || p.is_a?(String) }.collect(&:to_sym)
          options[:ignore] = ignore
          data = format_validator.format_to(:json, data, options)
        end
        hash = JSON.parse(data)
        hash = {data_type.name.downcase => hash} if options[:include_root]
        if options[:pretty]
          JSON.pretty_generate(hash)
        else
          options[:include_root] ? hash.to_json : data
        end
      end

      def to_xml(options = {})
        if orm_model.data_type.records_methods.any? { |alg| alg.name == 'to_xml' }
          return method_missing(:to_xml, options)
        end
        data = self.data
        data_type = orm_model.data_type
        options = options.merge(schema_data_type: data_type.schema_data_type)
        unless (format_validator = data_type.format_validator).nil? || format_validator.data_format == :xml
          data = format_validator.format_to(:xml, data, options)
        end
        Nokogiri::XML::Document.parse(data)
        data
      end

      def to_xml_element(options = {})
        if orm_model.data_type.records_methods.any? { |alg| alg.name == 'to_xml_element' }
          return method_missing(:to_xml_element, options)
        end
        data = self.data
        data_type = orm_model.data_type
        options = options.merge(schema_data_type: data_type.schema_data_type)
        unless (format_validator = data_type.format_validator).nil? || format_validator.data_format == :xml
          data = format_validator.format_to(:xml, data, options)
        end
        Nokogiri::XML::Document.parse(data).root
      end

      def to_edi(options = {})
        if orm_model.data_type.records_methods.any? { |alg| alg.name == 'to_edi' }
          return method_missing(:to_edi, options)
        end
        data = file.data
        data_type = orm_model.data_type
        options = options.merge(schema_data_type: data_type.schema_data_type)
        unless (format_validator = data_type.format_validator).nil? || format_validator.data_format == :edi
          data = format_validator.format_to(:edi, data, options)
        end
        data
      end
    end
  end
end
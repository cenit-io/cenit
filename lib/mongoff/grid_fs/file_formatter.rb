module Mongoff
  module GridFs
    module FileFormatter

      def to_hash(options = {})
        if (json = native_hash_format(options, :to_hash)).is_a?(String)
          json = JSON.parse(json)
        end
        json
      end

      def to_json(options = {})
        if (json = native_hash_format(options, :to_json)).is_a?(Hash)
          json = json.to_json
        end
        json
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
        if (errors = Nokogiri::XML::Document.parse(data).errors).present?
          fail "Invalid XML format: #{errors.to_sentence}"
        end
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
          begin
            data = format_validator.format_to(:edi, data, options)
          rescue Exception => ex
            fail "Invalid EDI format: #{ex.message}"
          end
        end
        data
      end

      private

      def native_hash_format(options = {}, alg_delegator_method)
        if (alg_methods = orm_model.data_type.records_methods.select { |alg| %w(to_hash to_json).include?(alg.name) }).present?
          alg_delegator_method =
            if alg_methods.length == 1 || alg_methods[0].name == alg_delegator_method.to_s
              alg_methods[0].name
            else
              alg_methods[1].name
            end
          return method_missing(alg_delegator_method, options)
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
        begin
          hash = JSON.parse(data)
        rescue Exception => ex
          begin
            fail "Invalid JSON format: #{ex.message}"
          rescue
            fail 'Invalid JSON format'
          end
        end
        hash = { data_type.name.downcase => hash } if options[:include_root]
        hash
      end
    end
  end
end
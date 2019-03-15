module Setup
  module FormatValidator

    def data_format
      fail NotImplementedError
    end

    def content_type
      "application/#{data_format}"
    end

    def file_extension
      if (types = MIME::Types[content_type])
        types.each do |type|
          unless (extensions = type.extensions).empty?
            return extensions.first
          end
        end
      end
      nil
    end

    def format_method
      "to_#{data_format}"
    end

    def format_options
      {}
    end

    def format_from_json(data, options = {})
      format_from(:json, data, options)
    end

    def format_from_xml(data, options = {})
      format_from(:xml, data, options)
    end

    def format_from_edi(data, options = {})
      format_from(:edi, data, options)
    end

    def format_from(format, data, options = {})
      if format == data_format
        data
      elsif data_type = options.delete(:schema_data_type) || schema_data_type
        data_type.send("new_from_#{format}", data).send(format_method, format_options)
      else
        fail "Can not format from #{format} (schema data type is not configured)"
      end
    end

    def format_to(format, data, options= {})
      if data_type = options.delete(:schema_data_type) || schema_data_type
        data_type.send("new_from_#{data_format}", data, format_options).send("to_#{format}", options)
      else
        fail "Can not format to #{format} (schema data type is not configured)"
      end
    end

  end
end

module Setup
  module DataTypeValidator

    def data_format
      data_type.schema.schema_type.to_s.split('_').first.to_sym
    end

    def content_type
      "application/#{data_format}"
    end

    def file_extension
      if types = MIME::Types[content_type]
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

    def format_from_json(data)
      format_from(:json, data)
    end

    def format_from_xml(data)
      format_from(:xml, data)
    end

    def format_from_edi(data)
      format_from(:edi, data)
    end

    def format_from(format, data)
      if format == data_format
        data
      else
        data_type.send("new_from_#{format}", data).send(format_method, format_options)
      end
    end

    def format_to(format, data, options= {})
      data_type.send("new_from_#{data_format}", data, format_options).send("to_#{format}", options)
    end
  end
end
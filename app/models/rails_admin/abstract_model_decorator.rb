# rails_admin-1.0 ready
module RailsAdmin
  AbstractModel.class_eval do
    def model_class
      @model_name.constantize
    end

    def model
      m = model_class
      if (persistence_options = Thread.current["[cenit][#{m}]:persistence-options"])
        m.with(persistence_options)
      else
        m
      end
    end

    def parse_field_value(field, value)
      case value
      when Hash
        value.map { |key, v| [key, parse_field_value(field, v)] }.to_h
      when Array
        value.map { |v| parse_field_value(field, v) }
      else
        field.parse_value(value)
      end
    end

    def embedded_in?(abstract_model = nil)
      embedded?
    end

    def to_param
      #Patch
      m = model
      if (custom_to_param = m.instance_variable_get(:@ra_custom_to_param))
        custom_to_param.call(m)
      else
        @model_name.split('::').last.underscore
      end
    end

    def api_path
      return nil unless Setup::BuildInDataType.build_ins[@model_name]
      unless (path = config.api_path)
        tokens = @model_name.split('::')
        path = tokens.pop.underscore
        if tokens.length.positive?
          path = tokens.collect(&:underscore).join('/') + "/#{path}"
        else
          path = "#{Setup.to_s.underscore}/#{path}"
        end
      end
      path
    end
  end
end

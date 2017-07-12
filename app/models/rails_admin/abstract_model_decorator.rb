module RailsAdmin
  AbstractModel.class_eval do

    def embedded_in?(abstract_model = nil)
      embedded?
    end

    def to_param
      @model_name.split('::').last.underscore
    end

    def api_path
      return nil unless Setup::BuildInDataType.build_ins[@model_name]
      tokens = @model_name.split('::')
      path = tokens.pop.underscore
      if tokens.length > 0
        path = tokens.collect(&:underscore).join('/') + "/#{path}"
      else
        path = "#{Setup.to_s.underscore}/#{path}"
      end
      path
    end
  end
end

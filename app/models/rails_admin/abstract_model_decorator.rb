module RailsAdmin
  AbstractModel.class_eval do

    def embedded_in?(abstract_model = nil)
      embedded?
    end

    def to_param
      @model_name.split('::').last.underscore
    end
  end
end

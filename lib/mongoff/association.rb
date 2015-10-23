module Mongoff
  class Association

    attr_reader :model, :name, :macro

    def initialize(model, name, macro)
      @model = model
      @name = name
      @macro = macro
    end

    def klass
      @klass ||= model.property_model(name)
    end

    def nested?
      @nested ||= !model.property_schema(name)['referenced']
    end

    def method_missing(*args)
      nil
    end
  end
end
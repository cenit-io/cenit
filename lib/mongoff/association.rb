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

    def inverse_of
      nil
    end

    def many?
      @many ||= macro.to_s =~ /many/
    end
  end
end
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

    def referenced?
      if @referenced.nil?
        @referenced = model.property_schema(name)['referenced']
      else
        @referenced
      end
    end

    def embedded?
      nested?
    end

    def nested?
      !referenced?
    end

    def inverse_of
      nil
    end

    def many?
      @many ||= macro.to_s =~ /many/
    end

    def foreign_key
      nested? ? nil : model.attribute_key(name).to_s
    end
  end
end
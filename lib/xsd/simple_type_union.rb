module Xsd
  class SimpleTypeUnion < BasicTag

    tag 'union'

    attr_reader :types

    def initialize(parent, types=nil)
      super(parent)
      @types = Set.new
      if types
        types = types.split(' ') if types.is_a?(String)
        types.each { |type| @types << type }
      end
    end

    def when_simpleType_end(simpleType)
      types << simpleType
    end

    def to_json_schema
      #{'oneOf' => types.collect { |type| type.to_json_schema }}
      {'type' => 'string'}
    end
  end
end

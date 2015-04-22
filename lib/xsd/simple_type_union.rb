module Xsd
  class SimpleTypeUnion < BasicTag

    tag 'union'

    attr_reader :types

    def initialize(parent, types=[])
      super(parent)
      @types = Set.new
      types.each { |type| @types << type } if types
    end

    def when_simpleType_end(simpleType)
      types << simpleType
    end

    def to_json_schema
      {'anyOf' => types.collect { |type| type.to_json_schema }}
    end
  end
end

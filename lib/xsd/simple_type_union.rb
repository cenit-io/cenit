module Xsd
  class SimpleTypeUnion < BasicTag

    tag 'union'

    attr_reader :types

    def initialize(args)
      super
      @types = Set.new
      if types = args[:types]
        types.each { |type| @types << type }
      end
    end

    def when_simpleType_end(simpleType)
      types << simpleType
    end

    def to_json_schema
      {'anyOf' => types.collect { |type| type.to_json_schema }}
    end
  end
end

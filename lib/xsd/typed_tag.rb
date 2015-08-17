module Xsd
  class TypedTag < NamedTag

    attr_reader :type_name

    def initialize(args)
      super
      @type_name = attributeValue(:type, args[:attributes])
    end
  end
end

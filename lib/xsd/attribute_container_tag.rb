module Xsd
  module AttributeContainerTag

    attr_reader :attributes

    def initialize_attribute_container_tag(args)
      @attributes = []
    end

    def attribute_start(attributes = [])
      @attributes << (attr = Xsd::Attribute.new(parent: self, attributes: attributes))
      attr
    end
  end
end
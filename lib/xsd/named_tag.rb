module Xsd
  class NamedTag < AttributedTag

    attr_reader :name

    def initialize(args)
      super
      @name = attributeValue(:name, args[:attributes])
    end

    def tag_name
      self.class.try(:tag_name)
    end
  end
end
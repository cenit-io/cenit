module Xsd
  class NamedTag < AttributedTag

    attr_reader :name

    def initialize(parent, attributes)
      super
      _, @name = attributes.detect { |a| a[0] == 'name' }
    end

    def tag_name
      self.class.try(:tag_name)
    end
  end
end
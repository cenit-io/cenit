module Xsd
  class NamedTag < AttributedTag

    attr_reader :name

    def initialize(parent, attributes)
      super
      _, @name = attributes.detect { |a| a[0] == 'name' }
    end

    def tag_name
      self.class.tag_name rescue nil
    end
  end
end
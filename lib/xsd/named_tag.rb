module Xsd
  class NamedTag < BasicTag

    attr_reader :name

    def initialize(parent, attributes)
      super(parent)
      _, @name = attributes.detect { |a| a[0] == 'name' }
    end

    def tag_name
      self.class.tag_name rescue nil
    end
  end
end
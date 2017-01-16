module Xsd
  class AttributedTag < BasicTag

    def initialize(args)
      super
      @xmlns = {'' => nil}
      args[:attributes].each { |attr| @xmlns[attr[0].from(attr[0].index(':') + 1)] = attr[1] if attr[0] =~ /\Axmlns:/ }
      if (default = @xmlns.delete(''))
        @xmls[:default] = default
      end
    end

    def tag_name
      self.class.try(:tag_name)
    end

    def xmlns(ns)
      @xmlns[ns] || super
    end

    def attributeValue(name, attributes)
      name = name.to_s
      (a = attributes.detect { |a| a[0] == name }) ? a[1] : nil
    end
  end
end
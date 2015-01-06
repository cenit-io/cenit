module Xsd
  class AttributedTag < BasicTag

    def initialize(parent, attributes)
      super(parent)
      @xmlns = {'' => nil}
      attributes.each do |attr|
        if attr[0] =~ /\Axmlns:/
          @xmlns[attr[0].from(attr[0].index(':') + 1)] = attr[1]
        end
      end
      if default = @xmlns.delete('')
        @xmls[:default] = default
      end
    end

    def tag_name
      self.class.tag_name rescue nil
    end

    def xmlns(ns)
      if xmlns = @xmlns[ns]
        xmlns
      else
        super
      end
    end
  end
end
module Xsd
  class Attribute < TypedTag

    tag 'xs:attribute'

    attr_reader :use

    def initialize(parent, attributes)
      super
      _, @use = attributes.detect { |a| a[0] == 'use' }
    end

    def required?
      use == 'required'
    end

    def when_end_xs_simpleType(simpleType)
      if type = simpleType.type rescue nil
        @type = type
      end
    end

    def eql?(obj)
      obj.class == Attribute && obj.name == name
    end

    def type
      @type ? @type : type_name
    end

  end
end

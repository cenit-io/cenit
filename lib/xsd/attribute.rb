module Xsd
  class Attribute < TypedTag

    tag 'attribute'

    attr_reader :use

    def initialize(parent, attributes)
      super
      _, @use = attributes.detect { |a| a[0] == 'use' }
    end

    def required?
      use == 'required'
    end

    def when_simpleType_end(simpleType)
      if type = simpleType.try(:type)
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

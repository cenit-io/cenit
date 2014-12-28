module Xsd
  class TypedTag < NamedTag

    attr_reader :type_name

    def initialize(parent, attributes)
      super
      _, @type_name = attributes.detect { |a| a[0] == 'type' }
    end
  end
end

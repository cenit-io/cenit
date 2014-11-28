module Xsd
  class TypeBuilderTag < NamedTag

    attr_reader :type

    def pop_events
      (type && name) ? {:type_defined => name} : nil
    end
  end
end
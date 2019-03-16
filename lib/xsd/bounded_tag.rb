module Xsd
  module BoundedTag
    attr_reader :max_occurs
    attr_reader :min_occurs

    def initialize_bounds(args)
      max_occurs = attributeValue(:maxOccurs, args[:attributes])
      @max_occurs =
        if max_occurs
          max_occurs == 'unbounded' ? :unbounded : max_occurs.to_i
        else
          1
        end
      min_occurs = attributeValue(:minOccurs, args[:attributes])
      @min_occurs =
        if min_occurs
          min_occurs == 'unbounded' ? 0 : min_occurs.to_i
        else
          1
        end
    end
  end
end
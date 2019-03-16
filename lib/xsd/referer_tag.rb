module Xsd
  module RefererTag
    attr_reader :ref

    def initialize_referer_tag(args)
      @ref = attributeValue(:ref, args[:attributes])
    end
  end
end
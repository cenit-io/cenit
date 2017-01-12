module Xsd
  class Documentation < AttributedTag

    tag 'documentation'

    attr_reader :source, :content

    def initialize(args)
      super
      @source = attributeValue(:source, args[:attributes])
      @content = ''
    end

    def characters(string)
      @content += string
    end

    def to_string
      if source
        "#{source}: #{content}"
      else
        content
      end
    end
  end
end
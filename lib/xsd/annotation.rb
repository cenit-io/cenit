module Xsd
  class Annotation < AttributedTag

    tag 'annotation'

    attr_reader :documentations

    def initialize(args)
      super
      @documentations = []
    end

    def when_documentation_end(documentation)
      documentations << documentation
    end
  end
end
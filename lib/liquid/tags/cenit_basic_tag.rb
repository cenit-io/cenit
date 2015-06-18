module Liquid
  class CenitBasicTag < Tag
    class << self
      def tag(name)
        Template.register_tag(name, self)
      end
    end
  end
end
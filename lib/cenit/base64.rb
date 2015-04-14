
module Cenit
    class Base64 < Eval

      def initialize(tag_name, value, tokens)
        super
        @value = value
      end

      def render(context)
        ::Base64.encode64(super).gsub("\n", '')
      end
    end
end
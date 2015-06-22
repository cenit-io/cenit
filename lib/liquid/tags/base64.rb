
module Liquid
    class Base64 < Eval

      tag :base64

      def render(context)
        ::Base64.encode64(super).gsub("\n", '')
      end
    end
end

module Cenit
    class Base64 < Eval

      def render(context)
        ::Base64.encode64(super).gsub("\n", '')
      end
    end
end
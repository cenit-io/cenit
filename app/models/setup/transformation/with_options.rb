module Setup
  module Transformation
    class WithOptions < Setup::Transformation::AbstractTransform

      def initialize(options)
        @options = options
      end

      def method_missing(symbol, *args)
        if args.length == 0 && value = @options[symbol]
          value
        else
          super
        end
      end

      def respond_to?(symbol)
        @options[symbol] || super
      end

      def source
        respond_to?(:sources) ? sources.current : method_missing(:source)
      end

      def next_source
        sources.next
      end
    end
  end
end

require 'liquid/drop'

module Cenit
  module Liquidfier
    def to_liquid
      @cenit_liquid_drop ||= Cenit::Liquidfier::Drop.new(self)
    end

    class Drop < Liquid::Drop

      def initialize(object)
        @object = object
      end

      def invoke_drop(method_or_key)
        if Capataz.instance_response_to?(@object, method_or_key)
          @object.send(method_or_key)
        else
          before_method(method_or_key)
        end
      end

      def [](method_or_key)
        invoke_drop(method_or_key)
      end

      def respond_to?(*args)
        ((args[0] == :each) && Capataz.instance_response_to?(@object, :each)) || super
      end

      def method_missing(symbol, *args, &block)
        if symbol == :each && Capataz.instance_response_to?(@object, :each)
          @object.send(symbol, *args, &block)
        else
          super
        end
      end

    end
  end
end
module Setup
  module Transformation
    class LiquidConversionTransform

      class << self

        def run(options = {})
          LiquidRendering.convert(options)
        end

      end
    end
  end
end

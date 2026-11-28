module Setup
  module Transformation
    class LiquidExportTransform

      class << self

        def run(options = {})
          LiquidRendering.export(options)
        end

      end
    end
  end
end

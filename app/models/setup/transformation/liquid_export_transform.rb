module Setup
  module Transformation
    class LiquidExportTransform

      class << self

        def run(options = {})
          template = Liquid::Template.parse(options[:code])
          source_hash = options[:source].to_hash
          template.render(source_hash)
        end

      end
    end
  end
end

module Setup
  module Transformation
    class LiquidExportTransform

      class << self

        def run(options = {})
          template = Liquid::Template.parse(options[:transformation])
          source_hash = JSON.parse(options[:source].to_json)
          template.render(source_hash)
        end

      end
    end
  end
end

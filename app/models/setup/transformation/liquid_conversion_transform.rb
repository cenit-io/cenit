module Setup
  module Transformation
    class LiquidConversionTransform

      class << self

        def run(options = {})
          template = Liquid::Template.parse(options[:transformation])
          source_hash = JSON.parse(options[:source].to_json)
          options[:target].from_json(template.render(options.merge(source_hash)))
        end

      end
    end
  end
end

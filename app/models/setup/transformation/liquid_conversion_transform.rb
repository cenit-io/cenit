module Setup
  module Transformation
    class LiquidConversionTransform

      class << self

        def run(options = {})
          template = Liquid::Template.parse(options[:code])
          result = template.render(options.with_indifferent_access)
          options[:target].fill_from(result)
        end

      end
    end
  end
end

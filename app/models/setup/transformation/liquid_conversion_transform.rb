module Setup
  module Transformation
    class LiquidConversionTransform

      class << self

        def run(options = {})
          template = Liquid::Template.parse(options[:code])
          result = template.render(options.with_indifferent_access)
          options[:target] = options[:target_data_type].new_from(result)
        end

      end
    end
  end
end

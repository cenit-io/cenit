module Setup
  module Transformation
    class PrawnTransform < RenitTransform

      class << self
        def run(options = {})
          context = RenitTransform.new(options)
          context.send(:eval, "pdf = PrawnRails::Document.new;
            #{options[:transformation]}
            ;pdf.render;")
        end

        def types
          [:Export]
        end
      end
    end
  end
end
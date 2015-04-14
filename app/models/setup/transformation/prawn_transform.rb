module Setup
  module Transformation
    class PrawnTransform < WithOptions

      class << self

        def run(options = {})
          context = new(options)
          context.send(:eval, "pdf = PrawnRails::Document.new;
            #{options[:transformation]}
            ;pdf.render;")
        end

      end
    end
  end
end

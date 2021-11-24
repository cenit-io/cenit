module Setup
  module Transformation
    class HandlebarsTransform < Setup::Transformation::AbstractTransform

      class << self

        def run(options = {})
          handlebars = Handlebars::Handlebars.new
          handlebars.compile(options[:code]).call(options)
        end

      end
    end
  end
end

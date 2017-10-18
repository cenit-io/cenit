module Setup
  module Transformation
    class MappingTransform < Setup::Transformation::AbstractTransform

      class << self

        def run(options = {})
          options[:target] = options[:translator].do_map(options[:source])
        end

      end
    end
  end
end

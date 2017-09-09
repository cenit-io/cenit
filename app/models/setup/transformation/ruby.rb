module Setup
  module Transformation
    class Ruby < Setup::Transformation::AbstractTransform

      class << self

        def run(options = {})
          Cenit::BundlerInterpreter.run(options[:code], options, self_linker: options[:translator])
        end

      end
    end
  end
end

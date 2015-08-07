module Setup
  module Transformation
    class Ruby < Setup::Transformation::AbstractTransform

      class << self

        def run(options = {})
          Cenit::RubyInterpreter.run(options[:transformation], options[:translator], options)
        end

      end
    end
  end
end

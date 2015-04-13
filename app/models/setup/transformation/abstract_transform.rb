module Setup
  module Transformation
    class AbstractTransform

      class << self

        def metaclass
          class << self; self; end
        end

        def run(options = {})
          raise NotImplementedError
        end

      end
    end
  end
end
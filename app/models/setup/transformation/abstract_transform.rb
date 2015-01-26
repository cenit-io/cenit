module Setup
  module Transformation
    class AbstractTransform
      
      class << self
        def metaclass
          class << self; self; end
        end
      
        def self.run(transformation, document, options = {})
          raise NotImplementedError
        end
      end
      
    end  
  end
end
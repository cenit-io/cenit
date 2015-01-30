module Setup
  module Transformation
    class AbstractTransform
      
      class << self
        def metaclass
          class << self; self; end
        end
      
        def self.run(options = {})
          raise NotImplementedError
        end

        def types
          raise NotImplementedError
        end
      end
      
    end  
  end
end
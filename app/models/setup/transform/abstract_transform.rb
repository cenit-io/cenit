module Setup
  module Transform 
    class AbstractTransform
      
      def self.run(transformation, document, options = {})
        raise NotImplementedError
      end
      
    end  
  end
end
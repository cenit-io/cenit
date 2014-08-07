module Dashboard
  module Sales
    class SourcesController <  BaseController
      #TODO change by_time to By_staus or similar
      include Dashboard::ControllerHelpers::ByTime
      
      def compute(value)
        value.count
      end  
    end
  end
end
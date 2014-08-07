module Dashboard
  module Sales
    class TransactionsController < BaseController
      include Dashboard::ControllerHelpers::ByTime
      
      def klass_to_call
        Hub::Order  
      end
      
      def compute(value)
        value.count
      end  
    end
  end
end
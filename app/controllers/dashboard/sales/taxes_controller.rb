module Dashboard
  module Sales
    class TaxesController < BaseController
      include Dashboard::ControllerHelpers::ByTime
      
      def klass_to_call
        Hub::Order  
      end
      
      def compute(orders)
         orders.sum { |o| o.totals.nil? ? 0 : o.totals.tax }.round(2)
      end    
    end
  end
end
module Dashboard
  module Sales
    class AdjustmentsController < BaseController
      include Dashboard::ControllerHelpers::ByTime
      
      def compute(orders)
         orders.sum { |o| o.totals.nil? ? 0 : o.totals.adjustment }.round(2)
      end
    end    
  end
end
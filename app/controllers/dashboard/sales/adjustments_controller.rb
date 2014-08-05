module Dashboard
  module Sales
    class AdjustmentsController < SalesController
      def compute(orders)
         orders.sum { |o| o.totals.nil? ? 0 : o.totals.adjustment }.round(2)
      end
    end    
  end
end
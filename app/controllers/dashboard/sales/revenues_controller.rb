module Dashboard
  module Sales
    class RevenuesController < SalesController
      def compute(orders)
         orders.sum { |o| o.totals.nil? ? 0 : o.totals.order }.round(2)
      end  
    end
  end
end
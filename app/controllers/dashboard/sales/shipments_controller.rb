module Dashboard
  module Sales
    class ShipmentsController < SalesController
      def compute(orders)
         orders.sum { |o| o.totals.nil? ? 0 : o.totals.shipment }.round(2)
      end  
    end
  end
end
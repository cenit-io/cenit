module Dashboard
  module Sales
    class ItemsController < SalesController
      def compute(orders)
        orders.sum(&:items)
      end  
    end
  end  
end
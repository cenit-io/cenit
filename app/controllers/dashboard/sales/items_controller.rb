module Dashboard
  module Sales
    class ItemsController < SalesController
      def compute(orders)
        orders.sum { |order| order.line_items.sum{|line_item| line_item.quantity } }
      end  
    end
  end  
end
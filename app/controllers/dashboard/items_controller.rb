module Dashboard
  class ItemsController < SalesController
    def compute(value)
      value.sum { |order| order.line_items.sum{|line_item| line_item.quantity } }
    end  
  end
end
module Dashboard
  class OrdersController < SalesController
    def compute(value)
      value.count
    end  
  end
end
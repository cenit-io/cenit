module Dashboard
  module Sales
    class ItemsController < BaseController
      include Dashboard::ControllerHelpers::ByTime
      
      def compute(orders)
        orders.sum(&:items)
      end  
    end
  end  
end
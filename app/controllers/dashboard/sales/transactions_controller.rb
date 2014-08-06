module Dashboard
  module Sales
    class TransactionsController < SalesController
      def compute(value)
        value.count
      end  
    end
  end
end
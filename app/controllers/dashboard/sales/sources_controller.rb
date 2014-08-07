module Dashboard
  module Sales
    class SourcesController < SalesController
      def compute(value)
        value.count
      end  
    end
  end
end
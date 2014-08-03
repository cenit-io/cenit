module Dashboard
  class RevenuesController < SalesController
    def compute(value)
       value { |x| x.totals.nil? ? 0 : x.totals.order }.round(2)
      #value.sum { |order| order.totals.order if order && order.totals && order.totals.order }.round(2)
    end  
  end
end
module Dashboard
  class RevenuesController < SalesController
    def compute(value)
      value.sum { |x| x.totals.nil? ? 0 : x.totals.order }.round(2)
    end  
  end
end
module Dashboard
  class SalesController < BaseController
    before_action :get_params
    before_action :get_orders
    before_action :get_compare_orders
    
    def index
      @main_data = {}
      @orders.each {|o| @main_data[o.placed_on] = o.totals.order if o.totals } 
      
      @compare_data = {}
      @compare_orders.each {|o| @compare_data[ o.placed_on + @diff] = o.totals.order if o.totals }     
      set_data
    end  
    
    def by_week_days  
      set_data_by(:wday)
    end
     
    def by_hours  
      set_data_by(:hour)
    end 
    
    private
    
      def compute
        # Define in each class
      end  
    
      def set_data_by(fun)
        @main_data = collect_by(@orders, fun)
        @compare_data = collect_by(@compare_orders, fun)
        set_data 
      end 
       
      def set_data
        @data = [{:name => "#{@start_date} / #{@end_date}", :data => @main_data },
                 {:name => "#{@compare_start_date} / #{@compare_end_date}", :data => @compare_data }]
      end
         
      def collect_by(collection, fun )
        collection.group_by{|o| o.placed_on.send(fun)}.sort{|a,b| a[0]<=>b[0]}.collect do |c|
          case fun
          when :hour then [hours[c[0]], compute(c[1])]
          when :wday then [days[c[0]], compute(c[1])] 
          end
        end  
      end
      
      def get_params()
        @start_date =  Date.today - 3.months
        @end_date = Date.today 
        @compare_start_date = Date.today - 6.months
        @compare_end_date = Date.today - 3.months
        @diff = (@start_date - @compare_start_date).to_i.days
      end
        
      def get_orders
        @orders = Hub::Order.placed_on_between(@start_date, @end_date)
      end
      
      def get_compare_orders
        @compare_orders = Hub::Order.placed_on_between(@compare_start_date, @compare_end_date)
      end
      
  end
end
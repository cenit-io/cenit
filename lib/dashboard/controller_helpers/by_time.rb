module Dashboard
  module ControllerHelpers
    module ByTime
      extend ActiveSupport::Concern
      
      included do
        before_action :get_params
        before_action :get_data
        before_action :get_compare_data
      end  
      
      def klass_to_call
        # denifine where will be included
      end  
    
      def index
        #TODO build generic
        @main_data = {}
        @compare_data = {}  
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
          @main_set = collect_by(@data, fun)
          @compare_set = collect_by(@compare_data, fun)
          set_data 
        end 
       
        def set_data
          @data = [{:name => "#{@start_date} / #{@end_date}", :data => @main_set },
                   {:name => "#{@compare_start_date} / #{@compare_end_date}", :data => @compare_set }]
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
          #@diff = first_order.placed_on.to_time - first_order_compare.placed_on.to_time
        end
        
        def get_data
          @data = klass_to_call.placed_on_between(@start_date, @end_date)
        end
      
        def get_compare_data
          @compare_data = klass_to_call.placed_on_between(@compare_start_date, @compare_end_date)
        end
     end 
  end
end

module Dashboard
  class OverviewController < ApplicationController
    def index
      @users = User.all
      @orders=Hub::Order.all
    end

    def orders_statistics
      days=['sunday','monday','tuesday','wednesday','thursday','friday','saturday']
      orders = Hub::Order.all
      @orders_by_week_day = orders.group_by{|o| o.placed_on.wday}.sort{|a,b| a[0]<=>b[0]}.collect{|c| [days[c[0]],c[1].count] }
      @orders_by_hour = orders.group_by{|o| o.placed_on.to_datetime.hour}.sort{|a,b| a[0]<=>b[0]}.collect{|c| [c[0],c[1].count] }
    end

    def revenues_statistics
      days=['sunday','monday','tuesday','wednesday','thursday','friday','saturday']
      orders = Hub::Order.all
      @orders_by_week_day = orders.group_by{|o| o.placed_on.wday}.sort{|a,b| a[0]<=>b[0]}.collect{|c| [days[c[0]],c[1].count] }
    end
  end
end
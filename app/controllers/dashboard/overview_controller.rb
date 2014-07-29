module Dashboard
  class OverviewController < ApplicationController
    def index
      @users = User.all
      @orders=Hub::Order.all
    end

    def orders_statistics
      days=%w(sunday monday tuesday wednesday thursday friday saturday)
      hours = %w(12am 1am 2am 3am 4am 5am 6am 7am 8am 9am 10am 11am 12m 1pm 2pm 3pm 4pm 5pm 6pm 7pm 8pm 9pm 10pm 11pm)
      orders = Hub::Order.all
      @orders_by_week_day = orders.group_by{|o| o.placed_on.wday}.sort{|a,b| a[0]<=>b[0]}.collect{|c| [days[c[0]],c[1].count] }
      @orders_by_hour = orders.group_by{|o| o.placed_on.to_datetime.hour}.sort{|a,b| a[0]<=>b[0]}.collect{|c| [hours[c[0]],c[1].count] }
    end

    def revenues_statistics
      days=%w(sunday monday tuesday wednesday thursday friday saturday)
      hours = %w(12am 1am 2am 3am 4am 5am 6am 7am 8am 9am 10am 11am 12m 1pm 2pm 3pm 4pm 5pm 6pm 7pm 8pm 9pm 10pm 11pm)
      revenues = Hub::Order.all
      @revenues_by_day = revenues.find_all{|r| r.status == 'complete'}.group_by{|o| o.placed_on.wday}.sort{|a,b| a[0]<=>b[0]}.collect{|c| [days[c[0]],c[1].count] }
      @revenues_by_hour = revenues.find_all{|r| r.status == 'complete'}.group_by{|o| o.placed_on.hour}.sort{|a,b| a[0]<=>b[0]}.collect{|c| [hours[c[0]],c[1].count] }
    end
  end
end
module Dashboard
  class OverviewController < ApplicationController

    def index
      @users = User.all
      @orders=Hub::Order.all
    end

    def orders_statistics
      days=%w(sunday monday tuesday wednesday thursday friday saturday)
      hours = %w(0h 1h 2h 3h 4h 5h 6h 7h 8h 9h 10h 11h 12h 13h 14h 15h 16h 17h 18h 19h 20h 21h 22h 23h)
      #if Range Date Defined
      #orders = orders_by_date(from,to)
      @orders = orders_by_date

      @orders_by_week_day = @orders.group_by{|o| o.placed_on.wday}.sort{|a,b| a[0]<=>b[0]}.collect{|c| [days[c[0]],c[1].count] }

      @orders_by_hour = @orders.group_by{|o| o.placed_on.to_datetime.hour}.sort{|a,b| a[0]<=>b[0]}.collect{|c| [hours[c[0]],c[1].count] }

      #Orders Time Line
      orders_time_line = {}
      orders_time_line_comparison = {}
      @orders.each do |order|
        orders_time_line[order.placed_on.to_time.to_s] = order.totals.order unless order.totals.nil?
        orders_time_line_comparison[(order.placed_on + rand(15).days).to_time.to_s] = order.totals.order + rand(10) unless order.totals.nil?
      end
      @orders_time_line = [{:name => "Order's Revenue" ,:data => orders_time_line },
                           {:name => 'Random Compare To', :data => orders_time_line_comparison }]
    end

    def revenues_statistics
      days=%w(sunday monday tuesday wednesday thursday friday saturday)
      hours = %w(0h 1h 2h 3h 4h 5h 6h 7h 8h 9h 10h 11h 12h 13h 14h 15h 16h 17h 18h 19h 20h 21h 22h 23h)
      orders = orders_by_date
      @revenues_by_day = orders.find_all {|r| r.status == 'complete' } .group_by { |o| o.placed_on.wday } .sort { |a,b| a[0]<=>b[0] } .collect { |c| [days[c[0]],c[1].sum { |x| x.totals.nil? 0 : x.totals.order }.round(2)] }
      @revenues_by_hour = orders.find_all{|r| r.status == 'complete'} .group_by { |o| o.placed_on.hour } .sort { |a,b| a[0]<=>b[0] } .collect { |c| [hours[c[0]],c[1].sum{ |x| x.totals.nil? 0 : x.totals.order }.round(2)] }
    end

    def overview_statistics
      @revenues = Hub::Order.where(:status => 'complete').count
      @orders = Hub::Order.count
    end

    private

    def orders_by_date(from = nil, to = nil)
      orders = Hub::Order.all

      if from.nil? && to.present?
        orders.where{ |x| x.placed_on < to }
      elsif from.present? && to.nil?
        return orders.where{|x| x.placed_on > from }
      else
        orders
      end

    end

  end
end
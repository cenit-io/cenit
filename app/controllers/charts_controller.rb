  class ChartsController < ApplicationController

    def orders_by_time
      #@orders = Hub::Order.all
      #@orders=@orders.group_by{|o| o.placed_on }
      @x = Hub::Order.all.group_by_day(:placed_on)
      render json: @x.count
    end

  end

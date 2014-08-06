module Dashboard
  class OverviewController < BaseController
    def index
      @revenues = Hub::Order.where(:status => 'complete').count
      @orders = Hub::Order.count
      @overview_chart = {:Orders => @orders, :Revenues => @revenues }
    end
  end
end
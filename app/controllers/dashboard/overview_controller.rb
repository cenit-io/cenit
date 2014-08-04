module Dashboard
  class OverviewController < BaseController
    def index
      @revenues = Hub::Order.where(:status => 'complete').count
      @orders = Hub::Order.count
    end
  end
end
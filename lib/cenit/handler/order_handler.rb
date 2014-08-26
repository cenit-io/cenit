  module Cenit
    module Handler
      class OrderHandler < Base
        attr_reader :params

        def initialize(message, endpoint)
          super message
          @params = @payload[:orders]
        end

        def process
          count = 0
          params.each do |p|
            next if p[:id].empty?

            @order = Hub::Order.where(id: p[:id]).first
            if @order
              @order.update_attributes(p)
            else
              @order = Hub::Order.new(p)
            end
            count += 1 if @order.save
          end
          {'orders' => count}
        end

      end
    end
  end

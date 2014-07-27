  module Cenit
    module Handler
      class OrderHandler < Base
        attr_reader :params

        def initialize(message, endpoint)
          super message
          @params = @payload[:orders]
          @params.each {|p| p['connection_id'] = endpoint.id} if endpoint
        end

        def process
          order_ids = []
          params.each do |o|

            puts "ORDER -> #{o.inspect} #######################################"
            next if o[:id].empty?

            o[:totals_attributes] = process_totals(o.delete :totals) if o.has_key?(:totals)
            o.delete :adjustments
            o.delete :shipping_address
            o.delete :billing_address
            o.delete :payments

            @order = Hub::Order.where(id: o[:id]).first
            if @order
              @order.update_attributes(o)
            else
              @order = Hub::Order.new(o)
            end
            order_ids << @order.save ? @order.id : 0
          end
          response "Orders saved: #{order_ids.to_s}"
        end

        def process_line_items(line_items_params)
          return [] if line_items_params.nil?
          line_items = []
          line_items_params.each do |li|
            line_items << li
          end
          line_items
        end

        def process_totals(totals_params)
          return {} if totals_params.nil?
          totals_params
        end

      end
    end
  end

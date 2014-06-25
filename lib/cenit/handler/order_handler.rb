  module Cenit
    module Handler
      class OrderHandler < Base
        attr_reader :params

        def initialize(message, endpoint)
          super message
          @params = @payload[:orders]
          if endpoint
            @params.each {|p| p['connection_id'] = endpoint.id}
          end
        end

        # TODO: process all objects, no just the first one
        def process
          p = params.first
          @order = Hub::Order.where(id: p['id']).first
          if @order
            p.delete 'id'
            @order.update_attributes(p)
          else
            @order = Hub::Order.new(p)
          end

          if @order.save
            response "Order #{@order.id} saved"
          else
            response "Could not save the Order #{@order.errors.messages.inspect}", 500
          end
        end

      end
    end
  end

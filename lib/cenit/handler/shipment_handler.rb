  module Cenit
    module Handler
      class ShipmentHandler < Base
        attr_reader :params

        def initialize(message, endpoint)
          super message
          @params = @payload[:shipments]
        end

        def process
          count = 0
          params.each do |p|
            next if p[:id].empty?

            @shipment = Hub::Shipment.where(id: p[:id]).first
            if @shipment
              @shipment.update_attributes(p)
            else
              @shipment = Hub::Shipment.new(p)
            end
            count += 1 if @shipment.save
          end
          {'shipments' => count}
        end

      end
    end
  end

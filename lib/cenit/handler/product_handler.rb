module Cenit
  module Handler
    class ProductHandler < Base
      attr_reader :params, :options, :taxon_ids, :parent_id, :url

      def initialize(message, endpoint)
        super message
        @params = @payload[:products]
      end

      def process
        count = 0
        params.each do |p|
          next if p[:id].empty?

          @product = Hub::Product.where(id: p[:id]).first
          if @product
            @product.update_attributes(p)
          else
            @product = Hub::Product.new(p)
          end
          count += 1 if @product.save
        end
        {'products' => count}
      end

    end
  end
end

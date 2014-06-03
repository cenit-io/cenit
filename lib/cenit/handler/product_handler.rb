  module Cenit
    module Handler
      class ProductHandler < Base
        attr_reader :params, :options, :taxon_ids, :parent_id

        def initialize(message)
          super message
          @params = @payload[:products]
        end

        # TODO: process all products, no just the first one
        def process
          p = params.first
          @product = Hub::Product.where(id: p['id']).first
          if @product
			p.delete 'id'
			@product.update_attributes(p)
          else
			@product = Hub::Product.new(p)
          end

          if @product.save
            response "Product #{@product.id} saved"
          else
            response "Could not save the Product #{@product.errors.messages.inspect}", 500
           end
        end

      end
    end
  end

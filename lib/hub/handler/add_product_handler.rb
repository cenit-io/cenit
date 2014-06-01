  module Hub
    module Handler
      class AddProductHandler < Base
        attr_reader :params, :options, :taxon_ids, :parent_id

        def initialize(message)
          super message
          @params = @payload[:product]
        end

        def process
          params.delete :id
          @product = Product.new(params)
          if @product.save
            response "Product #{@product.id} created"
          else
            response "Could not save the Product #{@product.errors.messages.inspect}", 500
          end
        end

      end
    end
  end

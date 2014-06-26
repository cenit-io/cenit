  module Cenit
    module Handler
      class ProductHandler < Base
        attr_reader :params, :options, :taxon_ids, :parent_id

        def initialize(message, endpoint)
          super message
          @params = @payload[:products]
          if endpoint
            @params.each {|p| p['connection_id'] = endpoint.id}
          end
        end

        # TODO: process all products, no just the first one
        def process
          p = params.first
          
          if p[:taxons]
            taxons = []
            taxon_breadcrumb = p.delete :taxons
            taxon_breadcrumb.each do |breadcrumb|
              taxons << { "breadcrumb" => breadcrumb }
            end
            p["taxons_attributes"] = taxons
          end  
          
          @product = Hub::Product.where(id: p['id']).first
          if @product
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

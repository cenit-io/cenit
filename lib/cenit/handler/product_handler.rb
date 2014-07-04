  module Cenit
    module Handler
      class ProductHandler < Base
        attr_reader :params, :options, :taxon_ids, :parent_id

        def initialize(message, endpoint)
          super message
          @params = @payload[:products]
          if endpoint
            @params.each {|p| p[:connection_id] = endpoint.id}
          end
        end

        def process
          product_ids = []
          params.each do |p|
            p[:id] = p[:name].downcase.gsub(' ', '_') if p[:id].empty?
            p[:variants_attributes] = process_variants(p.delete :variants) if p[:variants].present?
            p[:taxons_attributes] = process_taxons(p.delete :taxons) if p[:taxons].present?
            p[:properties_attributes] = process_properties(p.delete :properties) if p[:properties].present?
            p.delete :options
            p.delete :images

            @product = Hub::Product.where(id: p[:id]).first
            if @product
              @product.update_attributes(p)
            else
              @product = Hub::Product.new(p)
            end
            product_ids << @product.save ? @product.id : 0
          end
          response "Products saved: #{product_ids.to_s}"
        end

        def process_variants(variants_params)
          variants = []
          variants_params.each do |variant|
            if variant[:options].present?
          if p[:taxons].present? 
              options = variant.delete :options
              variant[:options_attributes] = options.map {|k, v| {:option_type => k, :option_value => v}}
            end
            p["taxons_attributes"] = taxons
          end  
          
          
            if variant[:images].present?
              images = []
              images_attributes = variant.delete :images
              images_attributes.each do |image|
                image[:dimensions_attributes] = image.delete :dimensions if image[:dimensions].present?
                image["dimension_attributes"] = dimension_attributes
              end                  
              
                images << image
              end
              variant[:images_attributes] = images
            end
            variants << variant
          end
          variants
        end

        def process_taxons(taxons_params)
          taxons_params.map {|x| {:breadcrumb => x}}
        end

        def process_properties(properties_params)
          properties_params.map {|k, v| {:name => k, :presentation => v}}
        end

      end
    end
  end

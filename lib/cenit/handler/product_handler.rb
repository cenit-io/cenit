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
          
          #"taxons": [
          #  [ "Categories",  "Clothes", "T-Shirts" ],
          #  [ "Brands", "Spree" ],
          #  [ "Brands", "Open Source" ]
          #],

          # require transform in 

          #"taxons_attributes" => [
          #  { "breadcrumb" => ["Categories","Clothes", "T-Shirts"] },
          #  { "breadcrumb" => ["Brands","Spree"] },
          #  { "breadcrumb" => ["Brands","Open Source"] }
          #],        
          
          if p[:taxons].present? 
            taxons = []
            taxon_breadcrumb = p.delete :taxons
            taxon_breadcrumb.each do |breadcrumb|
              taxons << { "breadcrumb" => breadcrumb }
            end
            p["taxons_attributes"] = taxons
          end  
          
          
          if p[:images].present? 
            images = []
            images_attributes = p.delete :images
            images_attributes.each do |image|
              
              if image[:dimension].present? && ! image[:dimension].nil?
                dimension_attributes = image.delete :dimension
                image["dimension_attributes"] = dimension_attributes
              end                  
              
              images << image
            end  
            p["images_attributes"] = images
          end 
          
          
          #"properties": {
          #  "material": "cotton",
          #  "fit": "smart fit"
          #},
          
          # require transform in
          
          #"properties_attributes" => [
          #  { "name" => "material", 
          #    "presentation" => "cotton" },
          #  { "name" => "fit", 
          #    "presentation" => "smart fit" },
          #],
          
          if p[:properties].present?
            properties = []
            properties_attributes = p.delete :properties
            properties_attributes.each do |name, presentation|
              properties << {"name" => name, "presentation" => presentation }
            end
            p["properties_attributes"] = properties
          end    
                     
                     
        #  "variants" :[
        #        { "sku": "SPREE-T-SHIRT-S",
        #          "price": 39.99,
        #          "cost_price": 22.33,
        #          "quantity": 1,
        #          "options": {
        #            "color": "GREY",
        #            "size": "S"
        #          },
        #          "images": [
        #            { "url": "http://dummyimage.com/600x400/000/fff.jpg&text=Spree T-Shirt Grey Small",
        #              "position": 1,
        #              "title": "Spree T-Shirt - Grey Small",
        #              "type": "thumbnail",
        #              "dimensions": {
        #                "height": 220,
        #                "width": 100
        #              }
        #            }
        #          ]
        #        }
        #      ] 
        
        # require transform in 
        
        # "variants_attributes" => [
        #    {
        #      "sku" => "SPREE-T-SHIRT-S",
        #      "price" => 39.99,
        #      "cost_price" => 22.33,
        #      "quantity" => 1,
        #      "options_attributes" => [
        #        { "option_type" => "color",
        #          "option_value" => "GREY",
        #        },
        #        { "option_type" => "size",
        #          "option_value" => "S",
        #        },
        #      ],
        #      "images_attributes" => [
        #        {
        #          "url" => "http://dummyimage.com/600x400/000/fff.jpg&text=Spree T-Shirt Grey Small",
        #          "position" => 1,
        #          "title" => "Spree T-Shirt - Grey Small",
        #          "type" => "thumbnail",
        #          "dimension_attributes" => {
        #            "height" => 220,
        #            "width" => 100
        #          }
        #        }
        #      ]
        #    }
        #  ]
             
          
          if p[:variants].present? 
            variants = []
            variants_attributes = p.delete :variants
            
            
            variants_attributes.each do |variant|
                           
              if variant[:options].present? && ! variant[:options].nil?
                options = []
                options_attributes = variant.delete :options
                options_attributes.each do |option_type, option_value|
                  options << {"option_type" => option_type ,"option_value" => option_value}
                end  
                variant["options_attributes"] = options
              end  
              
              if variant[:images].present? && ! variant[:images].nil?
                images = []
                images_attributes = variant.delete :images
                images_attributes.each do |image|
                  
                  if image[:dimension].present? && ! image[:dimension].nil?
                    dimension_attributes = image.delete :dimension
                    image["dimension_attributes"] = dimension_attributes
                  end                  
                  
                  images << image
                end  
                variant["images_attributes"] = images
              end 
              
              variants << variant
            end
            p["variants_attributes"] = variants
          end  
          
          
          
          
          @product = Hub::Product.where(id: p['id']).first
          if @product
            @product.update_attributes(p)
          else
            @product = Hub::Product.new(p)
          end

          if @product.save
            puts "^^^^^^^^^^^^^^^^^^^^^^^^^^ params #{p.inspect}"
            response "Product #{@product.id} saved"
          else
            response "Could not save the Product #{@product.errors.messages.inspect}", 500
          end
        end

      end
    end
  end

require 'json'
require 'openssl'
require 'httparty'


module Cenit
  module Middleware
    class Consumer

      # TODO: create a noitfication from response
      def self.process(message)
        message = JSON.parse(message)

        if message["object"]["product"].present?
          p = message["object"]["product"]

          #"taxons" => [
          #  { "breadcrumb" => ["Categories","Clothes", "T-Shirts"] },
          #  { "breadcrumb" => ["Brands","Spree"] },
          #  { "breadcrumb" => ["Brands","Open Source"] }
          #],  
          
          # require transform in 
          
          #"taxons": [
          #  [ "Categories",  "Clothes", "T-Shirts" ],
          #  [ "Brands", "Spree" ],
          #  [ "Brands", "Open Source" ]
          #],
     
          if p["taxons"].present?
            unless (p["taxons"].nil? || p["taxons"] == [])
              taxon_attributes = p.delete "taxons"
              taxons = []
              taxon_attributes.each do |dic|
                taxons << dic["breadcrumb"]
              end              
            end
            p["taxons"] = taxons
          end

          #"properties" => [
          #  { "name" => "material", "presentation" => "cotton" },
          #  { "name" => "fit", "presentation" => "smart fit" },
          #],

          # require transform in
          
          #"properties": {
          #  "material": "cotton",
          #  "fit": "smart fit"
          #},
          
          if p["properties"].present? 
            unless (p["properties"].nil? || p["properties"] == [])
              properties_attributes = p.delete "properties"
              properties = {}
              properties_attributes.each do |dic|
                properties[dic['name']] = dic['presentation']
              end
            end            
            p["properties"] = properties
          end       
          
          
#          if p["images"].present? 
#            unless (p["images"].nil? || p["images"] == [])
#              images_attributes = p["images"]
#              images = {}
#              images_attributes.each do |image|
#                image.delete '_id' if image['_id'].present?
#                
#                if image["dimension"].present? 
#                  unless (image["dimension"].nil? || image["dimension"] == {})
#                    dimension_attributes = image.delete "dimension"
#                    image["dimension"].delete '_id' if image["dimension"]['_id'].present?
#                  end
#                end
#                                  
#                images << image
#              end
#            end            
#            p["images"] = images
#          end   

          # "variants" => [
          #    {
          #      "sku" => "SPREE-T-SHIRT-S",
          #      "price" => 39.99,
          #      "cost_price" => 22.33,
          #      "quantity" => 1,
          #      "options" => [
          #        { "option_type" => "color",
          #          "option_value" => "GREY",
          #        },
          #        { "option_type" => "size",
          #          "option_value" => "S",
          #        },
          #      ],
          #      "images" => [
          #        {
          #          "url" => "http://dummyimage.com/600x400/000/fff.jpg&text=Spree T-Shirt Grey Small",
          #          "position" => 1,
          #          "title" => "Spree T-Shirt - Grey Small",
          #          "type" => "thumbnail",
          #          "dimension" => {
          #            "height" => 220,
          #            "width" => 100
          #          }
          #        }
          #      ]
          #    }
          #  ]  

          # require transform in 
          
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
        
          if p['variants']
            
            variants = []
            variants_attributes = p.delete "variants"
            variants_attributes.each do |variant|
              #variant.delete('_id') if variant['_id'].present?
              
              if variant['options'].present?  
                
                unless (variant['options'].nil? || variant['options'] == [])
                  options = {}
                  options_attributes = variant.delete "options"
                  options_attributes.each do |option|
                    next unless option["option_type"].present?
  			       	    option_type = option["option_type"]
  			         		option_value = option["option_value"]
                    options["#{option_type}"] = "#{option_value}" 
                  end
                  variant["options"] = options
                end 
              end      
              
              variants << variant             
            end
            p['variants'] = variants

          end
          
          message["object"]["product"] = p           
        end  
        
        response = HTTParty.post(message['url'],
                   {
                      body: message['object'].to_json,
                      headers: {
                         'Content-Type'    => 'application/json',
                         'X_HUB_STORE'     => message['store'],
                         'X_HUB_TOKEN'     => message['token'],
                         'X_HUB_TIMESTAMP' => Time.now.utc.to_i.to_s
                      }
                   })
      end

    end
  end
end

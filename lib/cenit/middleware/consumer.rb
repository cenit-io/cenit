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
              taxon_breadcrumb = p["taxons"]
              p["taxons"] = []
              taxon_breadcrumb.each do |dic|
                p["taxons"] << dic["breadcrumb"]
              end              
            end
          end

          #"options" => [
          #  { "option_type" => "color","option_value" => "GREY" },
          #  { "option_type" => "size", "option_value" => "S" },
          #]    

          # require transform in 

          # "options": {
          #   "color": "GREY",
          #   "size": "S"
          # },
          
          if p["variants"].present? and p["variants"]["options"].present?
            v = p["variants"]
            unless (v["options"].nil? || v["options"] == [])
              options_attributes = v["options"]
              options = []
              options_attributes.each do |dic|
                options << {"#{dic["option_type"]}" => "#{dic["option_value"]}"}
              end
  
            end            
            p["variants"]["options"] = options
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

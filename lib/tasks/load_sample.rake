require 'ffaker'

namespace :sample do
  desc 'Loads Sample Data'
  task :load => :environment do
    
    Hub::Product.delete_all
    puts 'All Products Deleted.'
    Hub::Order.delete_all
    puts 'All Orders Deleted.'
    Hub::Address.delete_all
    puts 'All Address Deleted.'
    Hub::LineItem.delete_all
    puts 'All Line Item Deleted.'
    Hub::OrderTotal.delete_all
    puts 'All Orders Total Deleted.'
    
    all_taxons = [
      { "breadcrumb" => ["Categories","Bags"] },
      { "breadcrumb" => ["Categories","Mugs"] },
      { "breadcrumb" => ["Categories","Clothes", "T-Shirts" ] },
      { "breadcrumb" => ["Categories","Clothes", "Shirts" ] },
      { "breadcrumb" => ["Brands","Spree"] },
      { "breadcrumb" => ["Brands","Ruby"] },
      { "breadcrumb" => ["Brands","Apache"] },
      { "breadcrumb" => ["Brands","Rails"] },
      { "breadcrumb" => ["Brands","Open Source"] }
    ]
    
    sizes = ["Small","Medium","Large","Extra Large"]
    colors = ["white", "Red","Green","Blue", "Black", "Yelow", "Lilac"]
    all_options = sizes.product colors
    states = ['complete','processing','incomplete']
    
 all_properties =  [
          {"Manufacturer" => ["Wilson","Jerseys"]},
          {"Brand" => ["Wannabe Sports","Resiliance","Conditioned","Wannabe Sports","JK1002"]},
          {"Model" => ["JK1002","TL174","TL9002"]},
          {"Shirt Type" => ["Baseball Jersey","Jr. Spaghetti T","Ringer T", "Baseball Jersey","Jr. Spaghetti T"]},
          {"Sleeve Type" => ["Long","None","Short","Long"]},
          {"Made from" => ["100% cotton","90% Cotton, 10% Nylon","100% Vellum","90% Cotton, 10% Nylon"]},
          {"Fit" => ["Loose","Form","Loose"]},
          {"Gender" => ["Men's","Women's"]},
          {"Type" => ["Tote","Messenger","Mug","Stein","Tote","Messenger"]},
          {"Size" => [ %Q{15" x 18" x 6"},%Q{14 1/2" x 12" x 5"}, %Q{4.5" tall, 3.25" dia.},
    	            %Q{6.75" tall, 3.75" dia. base, 3" dia. rim}, %Q{6.75" tall, 3.75" dia. base, 3" dia. rim},
    				%Q{4.5" tall, 3.25" dia.}, %Q{14 1/2" x 12" x 5"} ]},
          {"Material" => ["Canvas","600 Denier Polyester"]}
        ]
        
          
    1.upto 20 do 
      name = "#{Faker::Product.product }"
      sku = name.underscore.gsub(' ', '-')
      cost_price = rand(10.5...100.5).round(2)
      taxons = all_taxons.shuffle.slice(0..rand(4))
      sub_set_prop = all_properties.shuffle.slice(0..rand(4))
      properties = sub_set_prop.map { |p| { "name" => p.keys[0], "presentation" => p.values[0].shuffle[0] } }
      options = all_options.shuffle.slice(0..(1 + rand(all_options.length)))
      height = 100 + rand(900)
      width = 100 + rand(900)
    
      variants = []
    
      options.each do |opt|
        height = 100 + rand(900)
        width = 100 + rand(900)
        size = opt[0]
        color = opt[1]
        variant = {
            "sku" => "#{sku}_#{size}_#{color}",
            "price" => cost_price + rand(30),
            "cost_price" => cost_price,
            "quantity" => rand(20),
            "options_attributes" => [
              {"option_type" => "color","option_value" => color},
              {"option_type" => "size","option_value" => size},
            ],
          
            "images_attributes" => [
              {
                "url" => "http://lorempixel.com/#{height}/#{width}/",
                "position" => 1,
                "title" => "Spree T-Shirt - Grey Small",
                "type" => "thumbnail",
                "dimension_attributes" => { "height" => height,"width" => height }
              }
            ]
          }
          variants << variant
      end  
    
      product = [ 
        {
          "id" => sku,
          "name" => name,
          "sku" => sku,
          "description" => Faker::Lorem.paragraphs(paragraph_count = 3),
          "price" => cost_price + rand(30),
          "cost_price" => cost_price,
          "available_on" => DateTime.now,
          "permalink" =>  sku,
          "meta_description" => nil,
          "meta_keywords" => nil,
          "shipping_category" => "Default",
          "taxons_attributes" => taxons,
          "options" => [ "color","size"],
          "properties_attributes" => properties,
          "images_attributes" => [
            {
              "url" => "http://lorempixel.com/#{height}/#{width}/",
              "position" => 1,
              "title" => sku,
              "type" => "thumbnail",
              "dimension_attributes" => { "height" => height,"width" => height }
            }
          ],
          "variants_attributes" => variants
        }
      ]
    
      Hub::Product.create!(product)
 
      # orders 
      1.upto 5 do
        total = rand(10.5...400.5).round(2)

        tax = rand 20
        shipping = rand 20
        adjustment = rand 20
        quantity = 1 + rand(5)
        item_price = total - ( tax + shipping)

        order = [ 
         {
            "id" => Faker::Product.letters(7),
            "status" => states[rand(3)],
            "channel" => "spree",
            "email" => "spree@example.com",
            "currency" => "USD",
            "placed_on" => DateTime.now - rand(20).months - rand(31).days-rand(24).hours-rand(60).minutes-rand(60).seconds,
            "totals_attributes" => {
              "item" => item_price,
              "adjustment" => adjustment,
              "tax" => tax,
              "shipping" => shipping,
              "payment" => item_price,
              "order" => item_price
            },
            "line_items_attributes" => [
              {
                "product_id" => sku,
                "name" => "Spree T-Shirt",
                "quantity" => quantity,
                "price" => item_price/quantity
              }
            ],
            "adjustments_attributes" => [
              {
                "name" => "Tax",
                "value" => 10.0
              },
              {
                "name" => "Shipping",
                "value" => 5.0
              },
              {
                "name" => "Shipping",
                "value" => 5.0
              }
            ],
            "shipping_address_attributes" => {
              "firstname" => Faker::Name.first_name,
              "lastname" => Faker::Name.last_name,
              "address1" => Faker::AddressUS.street_address,
              "address2" => Faker::AddressUS.secondary_address,
              "zipcode" => Faker::AddressUS.zip_code,
              "city" => Faker::AddressUS.city,
              "state" => Faker::AddressUS.state,
              "country" => "US",
              "phone" => "0000000000"
            },
            "billing_address_attributes" => {
              "firstname" => Faker::Name.first_name,
              "lastname" => Faker::Name.last_name,
              "address1" => Faker::AddressUS.street_address,
              "address2" => Faker::AddressUS.secondary_address,
              "zipcode" => Faker::AddressUS.zip_code,
              "city" => Faker::AddressUS.city,
              "state" => Faker::AddressUS.state,
              "country" => "US",
              "phone" => "0000000000"
            },
            "payments" => [
              {
                "number" => rand(1000),
                "status" => "completed",
                "amount" => item_price,
                "payment_method" => "Credit Card"
              }
            ]
          }

        ]
      
        Hub::Order.create!(order)
      end
      
    end
  end
end



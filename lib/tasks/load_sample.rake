require 'ffaker'

namespace :sample do
  desc 'Loads Sample Data'
  task :load => :environment do
    
    Hub::Product.delete_all
    
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
    
all_options = {    
    :size => ["Small","Medium","Large","Extra Large"],
    :color => ["white", "Red","Green","Blue", "Black", "Yelow", "Lilac"]
}
    
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
    
    name = "#{Faker::Product.product }"
    prod_sku = name.underscore.gsub(' ', '-')
    cost_price = rand(10.5...100.5).round(2)
    taxons = all_taxons.shuffle.slice(0..rand(4))
    sub_set_prop = all_properties.shuffle.slice(0..rand(4))
    properties = sub_set_prop.map { |p| { "name" => p.keys[0], "presentation" => p.values[0].shuffle[0] } }
    
    @attr = [ 
      {
        "id" => prod_sku,
        "name" => name,
        "sku" => prod_sku,
        "description" => Faker::Lorem.paragraphs(paragraph_count = 3),
        "price" => cost_price + rand(30),
        "cost_price" => cost_price,
        "available_on" => DateTime.now,
        "permalink" => prod_sku,
        "meta_description" => nil,
        "meta_keywords" => nil,
        "shipping_category" => "Default",
        "taxons_attributes" => taxons,
        "options" => [
          "color",
          "size"
        ],
        "properties_attributes" => properties,
        "images_attributes" => [
          {
            "url" => "http://lorempixel.com/#{100 + rand(900)}/#{100 + rand(900)}/",
            "position" => 1,
            "title" => "Spree T-Shirt - Grey Small",
            "type" => "thumbnail",
            "dimension_attributes" => {
              "height" => 220,
              "width" => 100
            }
          }
        ],
        "variants_attributes" => [
          {
            "sku" => "SPREE-T-SHIRT-S",
            "price" => cost_price + rand(30),,
            "cost_price" => cost_price,
            "quantity" => rand(20),
            "options_attributes" => [
              {
                "option_type" => "color",
                "option_value" => "GREY",
              },
              {
                "option_type" => "size",
                "option_value" => "S",
              },
            ],
            
            "images_attributes" => [
              {
                "url" => "http://dummyimage.com/600x400/000/fff.jpg&text=Spree T-Shirt Grey Small",
                "position" => 1,
                "title" => "Spree T-Shirt - Grey Small",
                "type" => "thumbnail",
                "dimension_attributes" => {
                  "height" => 220,
                  "width" => 100
                }
              }
            ]
          }
        ]
      }
    ]
    
    Hub::Product.create!(@attr)
    
  end
end



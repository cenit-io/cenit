require 'ffaker'

namespace :sample do
  desc "TODO"
  task load: :environment do

      Account.delete_all
      puts 'All Account Deleted.'
    
      User.delete_all
      puts 'All User Deleted.'
      
      Setup::Webhook.unscoped.delete_all
      puts 'All Webhook Deleted.'
  
      Setup::Connection.unscoped.delete_all
      puts 'All Connection Deleted.'
      
      Setup::ConnectionWebhook.unscoped.delete_all
      puts 'All ConnectionWebhook Deleted.'
    
      Setup::ModelSchema.unscoped.delete_all
      puts 'All ModelSchema Deleted.'
      
      Setup::Event.unscoped.delete_all
      puts 'All Event Deleted.'
      
      Setup::Flow.unscoped.delete_all
      puts 'All Flow Deleted.'

      ############  CONFIG TENANT ###############
      
      Account.create! [ { name: "Organization A"}, { name: "Organization B"} ]
    
      Account.all.each_with_index do |account, index|
        
        Account.current = account
        
        user1 = User.create!({
        		email: "user_#{index + 1}1@mail.com",
        		password: '12345678', 
        		password_confirmation: '12345678',
            account: account 
        	})
          
        user1.account = account
        user1.save(validate: false)
        
        account.owner = user1
          
        user2 = User.create!({
        		email: "user_#{index + 1}2@mail.com",
        		password: '12345678', 
        		password_confirmation: '12345678',
        	})  
          
        user2.account = account
        
        user2.save(validate: false)
        
        ############  LOAD MODELS ###############

        base_path = File.join(Rails.root, 'lib', 'jsons') 
        schemas = Dir.entries(base_path).select {|f| !File.directory?(f) && f != '.DS_Store' } 
        
        schemas.each do |file_schema|
          schema = File.read("#{base_path}/#{file_schema}")
          klass_name = file_schema.split('.json')[0].camelize
          
          model_schema_attributes = {
            module_name: 'Hub', 
            name: klass_name, 
            schema: schema,
            active: true,
            after_save_callback: %W[ Product Order Cart Payment Return ].include?(klass_name)
          }
          
          model_schema = Setup::ModelSchema.create!( model_schema_attributes )
          
          # Create default event 'created' and 'updated'
          # TODO: move this code for ModelSchema class
          
          if model_schema.after_save_callback.present?
            Setup::Event.create!(name: "created", model: model_schema) 
            Setup::Event.create!(name: "updated", model: model_schema)
          end
         
          klass = model_schema.instantiate
          klass.delete_all
          puts "All #{klass_name.pluralize} are deleted before load sample."
        end
        
        product = Setup::ModelSchema.find_by(name: 'Product')
        
        ############  CONFIG SETUP ###############
        
        webhook_attributes = [
          { 
            name: 'Add Product', 
            path: 'add_product',
            model: product
          },
          { 
            name: 'Update Product', 
            path: 'update_product',
            model: product
          }
        ]

        add_product = Setup::Webhook.create!(webhook_attributes[0])
        update_product = Setup::Webhook.create!(webhook_attributes[1])
        
        connection_attributes = [
          { 
            name: 'Store I', 
            url: 'http://localhost:3001/wombat', 
            key: '3001', 
            token: 'tresmiluno',
          },
          { 
            name: 'Store II', 
            url: 'http://localhost:3002/wombat', 
            key:'3002', 
            token: 'tresmildos'
          },
        ]
        
        store_I = Setup::Connection.create!(connection_attributes[0])
        store_II = Setup::Connection.create!(connection_attributes[1])
        
        add_product_store_I  = Setup::ConnectionWebhook.create!( connection: store_I, webhook: add_product )
        update_product_store_I  = Setup::ConnectionWebhook.create!( connection: store_I, webhook: update_product ) 
                
        add_product_store_II = Setup::ConnectionWebhook.create!( connection: store_II, webhook: add_product )
        update_product_store_II = Setup::ConnectionWebhook.create!( connection: store_II, webhook: update_product ) 
        
        product_created = Setup::Event.find_by(name: 'created', model: product)             
        product_updated = Setup::Event.find_by(name: 'updated', model: product)
        
        flow_attributes = [
          { 
            name: 'Add Product to Store I', 
            purpose: 'send',
            event: product_created,
            connection_webhook: add_product_store_I,
            active: true,
          },
          { 
            name: 'Update Product to Store I', 
            purpose: 'send',
            event: product_updated,
            connection_webhook: update_product_store_I,
            active: true,
          },
          { 
            name: 'Add Product to Store II', 
            purpose: 'send',
            event: product_created,
            connection_webhook: add_product_store_II,
            active: true,
          },
          { 
            name: 'Update Product to Store II', 
            purpose: 'send',
            event: product_updated,
            connection_webhook: update_product_store_II,
            active: true,
          }
        ]

        Setup::Flow.create!(flow_attributes)
        
        ############  SAMPLE DATA ###############
        
        all_taxons = [
          ["Categories","Bags"],
          ["Categories","Mugs"],
          ["Categories","Clothes", "T-Shirts" ],
          ["Categories","Clothes", "Shirts" ],
          ["Brands","Spree"],
          ["Brands","Ruby"],
          ["Brands","Apache"],
          ["Brands","Rails"],
          ["Brands","Open Source"]
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
    
      
        1.upto 50 do 
          name = "#{Faker::Product.product }"
          sku = name.underscore.gsub(' ', '-')
          cost_price = rand(10.5...100.5).round(2)
          taxons = all_taxons.shuffle.slice(0..rand(4))
          sub_set_prop = all_properties.shuffle.slice(0..rand(4))
          properties = {}
          sub_set_prop.each { |p| properties[ p.keys[0] ] = p.values[0].shuffle[0] }
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
                "options" => {
                  "color" => color,
                  "size" => size,
                },
      
  #              "images_attributes" => [
  #                {
  #                  "url" => "http://lorempixel.com/#{height}/#{width}/",
  #                  "position" => 1,
  #                  "title" => "Spree T-Shirt - Grey Small",
  #                  "type" => "thumbnail",
  #                  "dimension_attributes" => { "height" => height,"width" => height }
  #                }
  #              ]
              }
              variants << variant
          end  

          product = {
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
            "taxons" => taxons,
            "options" => [ "color","size"],
            "properties" => properties,
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

          Hub::Product.create!(product)

          # orders 
          num_orders = 1 + rand(20)
          1.upto num_orders do
            total = rand(100.5...400.5).round(2)

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
#                "totals_attributes" => {
#                  "item" => item_price,
#                  "adjustment" => adjustment,
#                  "tax" => tax,
#                  "shipping" => shipping,
#                  "payment" => item_price,
#                  "order" => item_price
#                },
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
                    "payment_method" => "Credit Card",
                    "source_attributes" => {
                        "name" => "#{Faker::Name.first_name} #{Faker::Name.last_name}",
                        "cc_type" => ['visa', 'american_express', 'master', 'discover'].shuffle.first,
                        "month" => 1 + rand(12),
                        "year" => rand(2015..2030),
                        "last_digits" => rand(10000),
                      }
                  }
                ]
              }

            ]
  
            Hub::Order.create!(order)
          end
  
        end

     end
  end
end
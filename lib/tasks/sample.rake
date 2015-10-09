require 'ffaker'

namespace :sample do
  desc "TODO"
  task load: :environment do

    Account.destroy_all
    puts 'All Account Deleted.'

    User.destroy_all
    puts 'All User Deleted.'

    Setup::Connection.unscoped.destroy_all
    puts 'All Connection Deleted.'

    Setup::ConnectionRole.unscoped.destroy_all
    puts 'All Connection Role Deleted.'

    Setup::Webhook.unscoped.destroy_all
    puts 'All Webhook Deleted.'

    Setup::SchemaDataType.unscoped.destroy_all
    puts 'All DataType Deleted.'

    Setup::Schema.unscoped.destroy_all
    puts 'All Schema Deleted.'

    Setup::Library.unscoped.destroy_all
    puts 'All Library Deleted.'

    Setup::Schedule.unscoped.destroy_all
    puts 'All Scheduler Deleted.'

    Setup::Batch.unscoped.destroy_all
    puts 'All Batch Deleted.'

    Setup::Event.unscoped.destroy_all
    puts 'All Event Deleted.'

    Setup::Flow.unscoped.destroy_all
    puts 'All Flow Deleted.'

    ############  CONFIG TENANT ###############

    Account.create! [{name: "Organization A"}, {name: "Organization B"}]

    Account.all.each_with_index do |account, index|

      Account.current = account

      user1 = User.create!({
                               email: "user_#{index + 1}1@mail.com",
                               password: '12345678',
                               password_confirmation: '12345678',
                               account: account
                           })
      user1.account = account
      user1.add_role :admin
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

      sample_library = Setup::Library.create(name: 'Sample')

      base_path = File.join(Rails.root, 'lib', 'jsons')
      schemas = Dir.entries(base_path).select { |f| !File.directory?(f) && f != '.DS_Store' }

      schema_models = []
      schemas.each do |file_schema|
        schema = File.read("#{base_path}/#{file_schema}")
        klass_name = file_schema.split('.json')[0].camelize
        puts "^^^^^^^^^^^^^^^^^^^^^^^^^^^ klass_name  #{klass_name.inspect}"
        schema_attributes = {
            library: sample_library,
            uri: klass_name,
            schema: schema,
            #active: true,
            #after_save_callback: %W[ Product Order Cart Payment Return ].include?(klass_name)
        }

        schema_models << Setup::Schema.create!(schema_attributes) rescue next

      end
      schema_models.each do |schema_model|
        schema_model.data_types.each do |data_type|
          if model = data_type.load_model
            model.delete_all
            puts "All #{data_type.name} are deleted before load sample."
          end
          # data_type.create_default_events
        end
      end


      product_data_type = Setup::SchemaDataType.where(name: 'Product').first
      next if product_data_type.nil?
      product_model = product_data_type.load_model
      next if product_model.nil?

      order_data_type = Setup::SchemaDataType.where(name: 'Order').first
      next if order_data_type.nil?
      order_model = order_data_type.load_model
      next if order_model.nil?

      ############  SAMPLE DATA ###############

      all_taxons = [
          ["Categories", "Bags"],
          ["Categories", "Mugs"],
          ["Categories", "Clothes", "T-Shirts"],
          ["Categories", "Clothes", "Shirts"],
          ["Brands", "Spree"],
          ["Brands", "Ruby"],
          ["Brands", "Apache"],
          ["Brands", "Rails"],
          ["Brands", "Open Source"]
      ]

      sizes = ["Small", "Medium", "Large", "Extra Large"]
      colors = ["white", "Red", "Green", "Blue", "Black", "Yelow", "Lilac"]
      all_options = sizes.product colors
      states = ['complete', 'processing', 'incomplete']

      all_properties = [
          {"Manufacturer" => ["Wilson", "Jerseys"]},
          {"Brand" => ["Wannabe Sports", "Resiliance", "Conditioned", "Wannabe Sports", "JK1002"]},
          {"Model" => ["JK1002", "TL174", "TL9002"]},
          {"Shirt Type" => ["Baseball Jersey", "Jr. Spaghetti T", "Ringer T", "Baseball Jersey", "Jr. Spaghetti T"]},
          {"Sleeve Type" => ["Long", "None", "Short", "Long"]},
          {"Made from" => ["100% cotton", "90% Cotton, 10% Nylon", "100% Vellum", "90% Cotton, 10% Nylon"]},
          {"Fit" => ["Loose", "Form", "Loose"]},
          {"Gender" => ["Men's", "Women's"]},
          {"Type" => ["Tote", "Messenger", "Mug", "Stein", "Tote", "Messenger"]},
          {"Size" => [%Q{15" x 18" x 6"}, %Q{14 1/2" x 12" x 5"}, %Q{4.5" tall, 3.25" dia.},
                      %Q{6.75" tall, 3.75" dia. base, 3" dia. rim}, %Q{6.75" tall, 3.75" dia. base, 3" dia. rim},
                      %Q{4.5" tall, 3.25" dia.}, %Q{14 1/2" x 12" x 5"}]},
          {"Material" => ["Canvas", "600 Denier Polyester"]}
      ]

      1.upto 5 do
        name = "#{Faker::Product.product }"
        sku = name.underscore.gsub(' ', '-')
        cost_price = rand(10.5...100.5).round(2)
        taxons = all_taxons.shuffle.slice(0..rand(4))
        sub_set_prop = all_properties.shuffle.slice(0..rand(4))
        properties = {}
        sub_set_prop.each { |p| properties[p.keys[0]] = p.values[0].shuffle[0] }
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
            "created_at" => DateTime.now - rand(100),
            "description" => Faker::Lorem.paragraphs(paragraph_count = 3),
            "price" => cost_price + rand(30),
            "cost_price" => cost_price,
            "available_on" => DateTime.now + rand(100),
            "permalink" => sku,
            "meta_description" => nil,
            "meta_keywords" => nil,
            "shipping_category" => "Default",
            "taxons" => taxons,
            "options" => ["color", "size"],
            "properties" => properties,
            #            "images_attributes" => [
            #                {
            #                    "url" => "http://lorempixel.com/#{height}/#{width}/",
            #                    "position" => 1,
            #                    "title" => sku,
            #                    "type" => "thumbnail",
            #                    #               "dimension_attributes" => { "height" => height,"width" => height }
            #                }
            #            ],
            #            "variants_attributes" => variants
        }


        #product_model.create!(product)

      end


      ############  CONFIG SETUP ###############

      connection_attributes = [
          {
              name: 'Store I',
              url: 'http://localhost:3001/wombat',
              key: "a#{index + 1}_3001",
              token: "a#{index + 1}_tresmiluno",
          },
          {
              name: 'Store II',
              url: 'http://localhost:3002/wombat',
          },
      ]

      store_I = Setup::Connection.create!(connection_attributes[0])
      store_II = Setup::Connection.create!(connection_attributes[1])

      webhook_attributes = [
          {
              name: 'Add Product',
              path: 'add_product',
              data_type: product_data_type,
              purpose: 'send'
          },
          {
              name: 'Update Product',
              path: 'update_product',
              data_type: product_data_type,
              purpose: 'send'
          }
      ]

      add_product_webhook = Setup::Webhook.create!(webhook_attributes[0])
      update_product_webhook = Setup::Webhook.create!(webhook_attributes[1])

      add_product_connection_role = Setup::ConnectionRole.create!(name: 'add_product')
      add_product_connection_role.webhooks << add_product_webhook
      add_product_connection_role.connections += [store_I, store_II]

      update_product_connection_role = Setup::ConnectionRole.create!(name: 'update_product')
      update_product_connection_role.webhooks << update_product_webhook
      update_product_connection_role.connections += [store_I, store_II]

      product_created = Setup::Event.find_by(name: 'Product on created_at', data_type: product_data_type)
      product_updated = Setup::Event.find_by(name: 'Product on updated_at', data_type: product_data_type)

      flow_attributes = [
          {
              name: 'Add Product',
              purpose: 'send',
              data_type: product_data_type,
              event: product_created,
              connection_role: add_product_connection_role,
              webhook: add_product_webhook,
              active: true,
          },
          {
              name: 'Update Product',
              purpose: 'send',
              data_type: product_data_type,
              event: product_updated,
              connection_role: update_product_connection_role,
              webhook: update_product_webhook,
              active: true,
          },
      ]

      Setup::Flow.create!(flow_attributes)

    end
  end
end
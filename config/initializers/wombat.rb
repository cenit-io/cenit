Spree::Wombat::Config.configure do |config|
#  config.connection_token = ENV["HUB_TOKEN"]
  config.connection_token = "123"
#  config.connection_id = ENV["HUB_STORE_ID"]
  config.connection_id = "456"
  config.push_objects = ["Spree::Order", "Spree::Product"]
  config.payload_builder = {
     "Spree::Order" => {:serializer => "Spree::Wombat::OrderSerializer", :root => "orders"},
     "Spree::Product" => {:serializer => "Spree::Wombat::ProductSerializer", :root => "products"},
  }
  config.push_url = "http://localhost:3002/wombat"
end

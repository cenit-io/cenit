require 'spec_helper'

describe Hub::Shipment do

  before(:each) do
    @attr = [ 
      {
        "id" => "12836",
        "order_id" => "R154085346",
        "email" => "spree@example.com",
        "cost" => 5.0,
        "status" => "ready",
        "stock_location" => "default",
        "shipping_method" => "UPS Ground (USD)",
        "tracking" => "12345678",
        "shipped_at" => "2014-02-03T17:33:55.343Z",
        "shipping_address_attributes" => {
          "firstname" => "Joe",
          "lastname" => "Smith",
          "address1" => "1234 Awesome Street",
          "address2" => "",
          "zipcode" => "90210",
          "city" => "Hollywood",
          "state" => "California",
          "country" => "US",
          "phone" => "0000000000"
        },
        "items_attributes" => [
          {
            "name" => "Spree T-Shirt",
            "product_id" => "SPREE-T-SHIRT",
            "quantity" => 1,
            "price" => 30.0,
 #           "options_attributes" => {
 #           }
          }
        ]
      },


      {

        "cost" => 5.0,
        "order_id" => "R154085348",
        "status" => "ready",
        "stock_location" => '',
        "shipping_method" => "UPS Ground (USD)",
        "tracking" => '',
        "updated_at" => '',
        "shipped_at" => '',
        "items_attributes" => [
          {
            "name" => "Spree T-Shirt",
           # "sku" => "SPREE-T-SHIRT",
           # "external_ref" => "",
            "quantity" => 1,
            "price" => 100.0,
            "variant_id" => 73,
            "options" => {
            }
          }
        ]
      }

  ]

  end

  it { should have_fields( :email, :cost, :status, :stock_location,
        :shipping_method,:tracking,:updated_at,:shipped_at) }

  it "should create a new instance given a valid attribute" do
    Hub::Shipment.create!(@attr)
  end

end  

require 'spec_helper'

describe Hub::Cart do

  before(:each) do
    @attr = [ 
     {
        "id" => "R154085346",
        "status" => "complete",
        "channel" => "spree",
        "email" => "spree@example.com",
        "currency" => "USD",
        "placed_on" => "2014-02-03T17:29:15.219Z",
        "totals_attributes" => {
          "item" => 200.0,
          "adjustment" => 20.0,
          "tax" => 10.0,
          "shipping" => 10.0,
          "payment" => 220.0,
          "order" => 220.0
        },
        "line_items_attributes" => [
          {
            "product_id" => "SPREE-T-SHIRT",
            "name" => "Spree T-Shirt",
            "quantity" => 2,
            "price" => 100.0
          }
        ],
        "adjustments" => [
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
        "billing_address_attributes" => {
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
        "payments" => [
          {
            "number" => 63,
            "status" => "completed",
            "amount" => 220.0,
            "payment_method" => "Credit Card"
          }
        ],

        "shipments_attributes" => [
          {
            "id" => "H51851735361",
            "number" => "H51851735361",
            "cost" => 5.0,
            "status" => "ready",
            "stock_location" => nil,
            "shipping_method" => "UPS Ground (USD)",
            "tracking" => nil,
            "updated_at" => nil,
            "shipped_at" => nil,
            "items_attributes" => [
              {
                "name" => "Spree T-Shirt",
                "sku" => "SPREE-T-SHIRT",
                "external_ref" => "",
                "quantity" => 1,
                "price" => 100.0,
                "variant_id" => 73,
                "options" => {
                }
              }
            ]
          },
          {
            "id" => "H51851735362",
            "number" => "H51851735362",
            "cost" => 5.0,
            "status" => "confirmed",
            "stock_location" => nil,
            "shipping_method" => "UPS Ground (USD)",
            "tracking" => nil,
            "updated_at" => nil,
            "shipped_at" => nil,
            "items_attributes" => [
              {
                "name" => "Spree T-Shirt",
                "sku" => "SPREE-T-SHIRT",
                "external_ref" => "",
                "quantity" => 1,
                "price" => 100.0,
                "variant_id" => 73,
                "options" => {
                }
              }
            ]
          }
        ]

      }

    ]

  end


  it { should validate_presence_of(:id) }

  it "should create a new instance given a valid attribute" do
    Hub::Cart.create!(@attr)
  end

end  

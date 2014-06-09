require 'spec_helper'

describe Hub::Product do

  before(:each) do
    @attr = [ 
      {
        "id" => "SPREE-T-SHIRT",
        "name" => "Spree T-Shirt",
        "sku" => "SPREE-T-SHIRT",
        "description" => "Awesome Spree T-Shirt",
        "price" => 35.0,
        "cost_price" => 22.33,
        "available_on" => "2014-01-29T14:01:28.000Z",
        "permalink" => "spree-tshirt",
        "meta_description" => nil,
        "meta_keywords" => nil,
        "shipping_category" => "Default",
        "taxons_attributes" => [
          { "breadcrumb" => [ "Categories","Clothes", "T-Shirts" ] },
          { "breadcrumb" => ["Brands","Spree"] },
          { "breadcrumb" => ["Brands","Open Source"] }
        ],
        "options" => [
          "color",
          "size"
        ],
        "properties_attributes" => [
          { "name" => "material", 
            "presentation" => "cotton" },
          { "name" => "fit", 
            "presentation" => "smart fit" },
        ],
        "images_attributes" => [
          {
            "url" => "http://dummyimage.com/600x400/000/fff.jpg&text=Spree T-Shirt",
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
            "price" => 39.99,
            "cost_price" => 22.33,
            "quantity" => 1,
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

  end

  it { should have_fields( :name, :sku, :description, :price, :cost_price,
             :available_on, :permalink, :meta_description, :meta_keywords,
             :shipping_category, :options ) }

  it { should have_many :variants }
  it { should have_many :images }
  it { should embed_many :taxons }
  it { should embed_many :properties }

  it { should accept_nested_attributes_for(:variants) }
  it { should accept_nested_attributes_for(:images) }
  it { should accept_nested_attributes_for(:properties) }
  it { should accept_nested_attributes_for(:taxons) }

  it { should validate_presence_of(:id) }
  it { should validate_presence_of(:name) }
  it { should validate_presence_of(:sku) }
  it { should validate_presence_of(:price) }
  it { should validate_presence_of(:available_on) }

  it { should validate_uniqueness_of(:sku)  }

  it { should validate_numericality_of(:price).greater_than(0) }

  it "should create a new instance given a valid attribute" do
    Hub::Product.create!(@attr)
  end

end

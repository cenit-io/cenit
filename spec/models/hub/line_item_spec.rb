require 'spec_helper'

describe Hub::LineItem do

  before(:each) do
    @attr =  [
          {
            "name" => "Spree T-Shirt",
            "product_id" => "SPREE-T-SHIRT",
            "quantity" => 1,
            "price" => 30.0,
            "options_attributes" => {
            }
          }
        ]


  end

  it { should have_fields( :name, :product_id, :quantity, :price )}

  it "should create a new instance given a valid attribute" do
    Hub::LineItem.create!(@attr)
  end

end  

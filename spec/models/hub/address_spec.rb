require 'spec_helper'

describe Hub::Address do

  before(:each) do
    @attr = [ 
        {
          "firstname" => "Joe",
          "lastname" => "Smith",
          "address1" => "1234 Awesome Street",
          "address2" => "",
          "zipcode" => "90210",
          "city" => "Hollywood",
          "state" => "California",
          "country" => "US",
          "phone" => "0000000000"
        }
    ]

  end


  it { should have_fields(:firstname, :lastname, :address1, :address2, 
:zipcode, :city, :state, :country, :phone) }

  it { should validate_presence_of(:firstname) }
  it { should validate_presence_of(:lastname) }
  it { should validate_presence_of(:address1) }
  it { should validate_presence_of(:zipcode) }
  it { should validate_presence_of(:city) }
  it { should validate_presence_of(:state) }
  it { should validate_presence_of(:country) }

  it "should create a new instance given a valid attribute" do
    Hub::Address.create!(@attr)
  end

end  

require 'spec_helper'

describe Hub::Address do
  it { should have_fields(:firstname, :lastname, :address1, :address2, 
:zipcode, :city, :state, :country, :phone) }

  it { should validate_presence_of(:firstname) }
  it { should validate_presence_of(:lastname) }
  it { should validate_presence_of(:address1) }
  it { should validate_presence_of(:zipcode) }
  it { should validate_presence_of(:city) }
  it { should validate_presence_of(:state) }
  it { should validate_presence_of(:country) }
end  

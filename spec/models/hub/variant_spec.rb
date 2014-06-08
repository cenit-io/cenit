require 'spec_helper'

describe Hub::Variant do

  it { should have_fields( :sku, :price, :cost_price, :quantity) }
  it { should validate_presence_of(:sku) }
  it { should validate_uniqueness_of(:sku) }

end

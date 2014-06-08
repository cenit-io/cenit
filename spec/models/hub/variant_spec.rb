require 'spec_helper'

describe Hub::Variant do

  it { should have_fields( :sku, :price, :cost_price, :quantity) }

end

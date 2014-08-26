require 'spec_helper'

describe Hub::LineItem do
  it { should have_fields( :name, :product_id, :quantity, :price )}
end  

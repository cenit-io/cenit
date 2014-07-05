require 'spec_helper'

describe Hub::Option do

  it { should have_fields( :option_type, :option_value) }
end

require 'spec_helper'

describe Hub::Image do
  it { should have_fields(:url, :position, :type, :title) }
  it { should validate_presence_of(:url) }
end

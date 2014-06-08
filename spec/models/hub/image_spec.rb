require 'spec_helper'

describe Hub::Image do
  it { should have_fields(:url, :position, :type, :title) }

end

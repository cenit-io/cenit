require 'spec_helper'

describe Hub::Property do
  it { should have_fields(:name, :presentation) }
  it { should validate_presence_of(:presentation) }
  it { should validate_presence_of(:name) }
end

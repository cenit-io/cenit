require 'spec_helper'

describe Hub::Taxon do
  it { should have_field(:breadcrumb).of_type(Array) }
end

require 'spec_helper'

describe User do
  it 'match the test user' do
    expect(User.current.email).to eq('test@cenit.io')
  end

  it 'match the test tenant' do
    expect(Tenant.current.name).to eq(User.current.email)
  end

  it 'contains the default first user roles' do
    expect(User.current.role_ids).to include(*Role.default_ids(true))
  end
end

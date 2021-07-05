require 'spec_helper'

describe User do

  before :all do
    User.current = default_user
  end

  it 'match the test user' do
    expect(User.current.email).to eq(default_user.email)
  end

  it 'contains the default first user roles' do
    expect(User.current.role_ids).to include(*Role.default_ids(true))
  end
end

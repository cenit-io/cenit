require 'rails_helper'

describe Role do
  it 'resolve all default roles' do
    roles = Role::FIRST_USER_DEFAULT_NAMES.map { |name| Role.where(name: name).first }
    expect(roles).to all(be)
  end
end

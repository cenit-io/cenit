require 'rails_helper'

RSpec.describe Api::V3::ApiController,
               type: :request,
               api_v3_integration: true,
               api_login: true do
  it 'authenticates with bearer token and resolves current user' do
    headers = v3_auth_headers(scope: 'read')

    get_json('/api/v3/setup/user/me', headers: headers)
    expect_status_in(:ok)

    body = json_response
    expect(body['id']).to be_present
    expect(body['email']).to be_present
  end
end


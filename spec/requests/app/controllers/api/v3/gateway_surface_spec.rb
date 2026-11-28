require 'rails_helper'

RSpec.describe 'API v3 gateway surface', type: :request, api_v3_requests: true, api_v3_integration: true do
  let(:headers) { v3_auth_headers(scope: 'read create digest') }

  it 'no longer registers the import and install task types' do
    expect(Setup.const_defined?(:ApiSpecImport, false)).to be(false)
    expect(Setup.const_defined?(:ApiPull, false)).to be(false)
    expect(Setup::PullImport).to be < Setup::Task
  end

  %w[api_spec api_spec_import api_pull].each do |model|
    it "does not expose the retired #{model} model" do
      get_json("/api/v3/setup/#{model}", headers: headers)
      expect(response).to have_http_status(:not_found)

      post_json("/api/v3/setup/#{model}", params: {}, headers: headers)
      expect(response).to have_http_status(:not_found)
    end
  end

  it 'still provides connections and resource paths' do
    %w[connection plain_webhook].each do |model|
      get_json("/api/v3/setup/#{model}", headers: headers)
      expect(response).to have_http_status(:ok)
      expect(json_response.fetch('items')).to be_an(Array)
    end
  end
end

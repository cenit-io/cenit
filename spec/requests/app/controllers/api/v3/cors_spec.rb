require 'rails_helper'

RSpec.describe Api::V3::ApiController,
               type: :request,
               api_v3_integration: true,
               api_v3_requests: true do
  describe 'OPTIONS /api/v3/*path' do
    it 'returns CORS headers for preflight requests' do
      options '/api/v3/setup/data_type', headers: {
        'Origin' => 'http://localhost:3002',
        'Access-Control-Request-Method' => 'POST'
      }

      expect(response).to have_http_status(:ok)
      expect(response.headers['Access-Control-Allow-Origin']).to eq('http://localhost:3002')
      expect(response.headers['Access-Control-Allow-Methods']).to include('OPTIONS')
      expect(response.headers['Access-Control-Allow-Headers']).to include('Authorization')
    end
  end
end

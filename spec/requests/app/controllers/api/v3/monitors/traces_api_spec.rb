require 'rails_helper'
RSpec.describe Api::V3::ApiController, type: :request do

  describe "GET /api/v3/setup/trace.json" do
    let(:response_data) {JSON.parse(response.body, symbolize_names: true)}

    context "Fail retrieve all existing Traces  "  do
      it "with missing header request" do
        get '/api/v3/setup/trace.json', as: :json
        expect(response).to have_http_status(:forbidden)
        expect(response_data[:error]).to eq("insufficient_scope")
        expect(response_data[:error_description]).to eq("The requested action is out of the access token scope")
      end

      it "with unauthorized token request"  do
        get '/api/v3/setup/trace.json', headers: {
          Authorization: "Bearer unauthorized_token }"
        }
        expect(response).to have_http_status(:unauthorized)
        expect(response_data[:error]).to eq("invalid_token")
        expect(response_data[:error_description]).to eq("Malformed authorization header")
      end  
    end

    context "successful retrieve all existing Traces"  do
      let(:access_token) do
        app = ::Setup::Application.create!(namespace: 'Test', name: 'Traces')
        access_grant = ::Cenit::OauthAccessGrant.create!(
            application_id: app.application_id,
            scope: 'read'
        )

        test_user = ::User.current
        access = ::Cenit::OauthAccessToken.for(
          app.application_id,
          access_grant.scope,
          test_user
        )

         return token = {
          Authorization: "Bearer #{access[:access_token]}"
        }
      end

      it "with authorized token request"  do
        get '/api/v3/setup/trace.json', headers: access_token
        
        expect(response).to have_http_status(:ok)
        expect(response_data[:count]).to be
        expect(response_data[:current_page]).to be
        expect(response_data[:data_type]).to be
        expect(response_data[:items]).to be
        expect(response_data[:total_pages]).to be
      end  
           
    end
  
  end
end

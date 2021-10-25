require 'rails_helper'
RSpec.describe Api::V3::ApiController, type: :request do

  describe "GET /api/v3/setup/storage.json" do

    context "Fail retrieve all existing Storages"  do
      it "with missing header request" do
        get '/api/v3/setup/storage.json'
        expect(response).to have_http_status(:forbidden)
        expect(json_response[:error]).to eq("insufficient_scope")
        expect(json_response[:error_description]).to eq("The requested action is out of the access token scope")
      end

      it "with unauthorized token request"  do
        get '/api/v3/setup/storage.json', headers: {
          Authorization: "Bearer unauthorized_token }"
        }
        expect(response).to have_http_status(:unauthorized)
        expect(json_response[:error]).to eq("invalid_token")
        expect(json_response[:error_description]).to eq("Malformed authorization header")
      end  
    end

    context "successful retrieve all existing Storages"  do

      it "with authorized token request"  do
        get '/api/v3/setup/storage.json', headers: header_token_authorization
        
        expect(response).to have_http_status(:ok)
        expect(json_response[:count]).to be
        expect(json_response[:current_page]).to eq 1
        expect(json_response[:current_page]).to be
        expect(json_response[:data_type]).to be
        expect(json_response[:items]).to be
        expect(json_response[:total_pages]).to be
      end  
           
    end
  
  end
end

require 'rails_helper'
RSpec.describe Api::V3::ApiController, type: :request do

  describe "POST /api/v3/setup/connection" do
    # Create an Connection
    it "With authorized token request" do
      request_data = {name: 'connection_test', url: "http://localhost:3002/cenit/test"}

      # The connection does not exists
      connection = Setup::Connection.where(name: request_data[:name]).first
      expect(connection).not_to be

      # Connection creation request success
      post '/api/v3/setup/connection', params: request_data, headers: headers_token_authorization[:header_token_create], as: :json
      expect(response).to have_http_status(:ok)
    end
  end

  describe "GET /api/v3/setup/connection/{id}" do
    # Retrieve an existing Connection
    it "Fail retrieve connection with bad id" do
      get "/api/v3/setup/connection/not_id", headers: header_token_authorization
      expect(response).to have_http_status(:not_found)
      expect(json_response[:status]).to eq("item not found")
    end

    it "Successful retrieve connection" do
      connection = FactoryGirl.create(:stores_connection)
      connection_id = connection.id

      get "/api/v3/setup/connection/#{connection_id}", headers: header_token_authorization
      expect(response).to have_http_status(:ok)
      expect(json_response).to include(:id, :name, :url)
      expect(json_response[:name]).to eq(connection.name)
      expect(json_response[:url]).to eq(connection.url)
    end
  end
end



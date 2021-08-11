require 'rails_helper'
RSpec.describe Api::V3::ApiController, type: :request do

  describe "POST /api/v3/setup/namespace" do
    # Create an Namespace
    it "With authorized token request" do
      request_data = {name: 'namespace_test', slug: "slug_test"}

      # The namespace does not exists
      namespace = Setup::Namespace.where(name: request_data[:name]).first
      expect(namespace).not_to be

      # Namespace creation request success
      post '/api/v3/setup/namespace', params: request_data, headers: headers_token_authorization[:header_token_create], as: :json
      expect(response).to have_http_status(:ok)

      # The created Namespace exists
      namespace = Setup::Namespace.where(name: request_data[:name]).first
      expect(namespace).to be
      expect(namespace.slug).to eq(request_data[:slug])
    end
  end

  describe "GET /api/v3/setup/namespace/{id}" do
    # Retrieve an existing Namespace
    it "Fail retrieve namespace with bad id" do
      get "/api/v3/setup/namespace/not_id", headers: header_token_authorization
      expect(response).to have_http_status(:not_found)
      expect(json_response[:status]).to eq("item not found")
    end

    it "Successful retrieve namespace" do
      namespace = FactoryGirl.create(:namespaces)
      namespace_id = namespace.id

      get "/api/v3/setup/namespace/#{namespace_id}", headers: header_token_authorization
      expect(response).to have_http_status(:ok)
      expect(json_response).to include(:id, :name, :slug)
      expect(json_response[:name]).to eq(namespace.name)
      expect(json_response[:slug]).to eq(namespace.slug)
    end
  end

  describe "POST /api/v3/setup/namespace/{id}" do
    # Update an Namespace:
    it "Successful Updates the specified Namespace" do
      namespace = FactoryGirl.create(:namespaces)
      namespace_id = namespace.id

      request_data = {name: 'update_namespace1', slug: 'update_slug1'}
      #Udate Namespace fields name and slug
      post "/api/v3/setup/namespace/#{namespace_id}", headers:  headers_token_authorization[:header_token_update], params: request_data
      expect(response).to have_http_status(:ok)
      expect(json_response[:name]).to eq(request_data[:name])
      expect(json_response[:slug]).to eq(request_data[:slug])
    end
  end

  describe "DELETE /api/v3/setup/namespace/{id}" do
    # Delete an existing Namespace
    it "Successful Delete the specified Namespace" do
      namespace = FactoryGirl.create(:namespaces)
      namespace_id = namespace.id
      namespace_name = namespace.name

      # The namespace exists
      namespace_to_delete = Setup::Namespace.where(name: namespace_name).first

      expect(namespace_to_delete).to be

      delete "/api/v3/setup/namespace/#{namespace_id}", headers:  headers_token_authorization[:header_token_delete]
      expect(response).to have_http_status(:ok)

      # The namespace does not exists
      namespace = Setup::Namespace.where(name: namespace_name).first
      expect(namespace).not_to be
    end
  end
end


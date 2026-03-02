require 'rails_helper'
require 'support/api/v2_user_helper'

RSpec.describe "Api::V2 Core CRUD", type: :request do
  include Api::V2UserHelper

  let!(:account) { Account.current || create(:account) }
  let!(:user) { User.current || create(:user) }
  let(:auth_headers) { v2_auth_headers(user, account) }

  before(:each) do
    User.current = user
    Account.current = account
    
    # Generate unique values for each test block
    @ns1 = Setup::Namespace.create!(name: "TestNamespace1-#{SecureRandom.hex(4)}", slug: "test_namespace_1_#{SecureRandom.hex(4)}")
    @ns2 = Setup::Namespace.create!(name: "TestNamespace2-#{SecureRandom.hex(4)}", slug: "test_namespace_2_#{SecureRandom.hex(4)}")
  end

  describe "GET /api/v2/setup/namespace" do
    it "returns list of namespaces with auth" do
      get "/api/v2/setup/namespace", env: { 'rack.input' => StringIO.new('') }, headers: auth_headers
      expect(response).to have_http_status(:ok)
      
      body = JSON.parse(response.body)
      expect(body['namespaces'].length).to be >= 2
    end
  end

  describe "POST /api/v2/setup/namespace" do
    it "creates a new namespace" do
      new_name = "TestNamespace-#{SecureRandom.hex}"
      payload = { name: new_name, slug: "slug_#{SecureRandom.hex}" }.to_json
      headers = auth_headers.merge('Content-Type' => 'application/json')
      
      post "/api/v2/setup/namespace", params: payload, headers: headers
      
      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body['success']['namespace']).to be_present

      # Re-set Account.current in case it was cleared by request middleware
      Account.current = account
      ns = Setup::Namespace.where(name: new_name).first
      expect(ns).to be_present
    end
  end

  describe "GET /api/v2/setup/namespace/:id (show)" do
    it "returns a specific namespace" do
      get "/api/v2/setup/namespace/#{@ns1.id}", env: { 'rack.input' => StringIO.new('') }, headers: auth_headers
      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body['name']).to eq(@ns1.name)
    end
  end

  describe "POST /api/v2/setup/namespace/:id (update)" do
    it "updates a namespace" do
      updated_name = "UpdatedNamespace-#{SecureRandom.hex}"
      payload = { name: updated_name }.to_json
      headers = auth_headers.merge('Content-Type' => 'application/json')

      post "/api/v2/setup/namespace/#{@ns2.id}", params: payload, headers: headers
      
      expect(response).to have_http_status(:ok)
      
      # Re-set Account.current in case it was cleared
      Account.current = account
      @ns2.reload
      expect(@ns2.name).to eq(updated_name)
    end
  end

  describe "DELETE /api/v2/setup/namespace/:id (destroy)" do
    it "destroys a namespace" do
      headers = auth_headers.merge('Content-Type' => 'application/json')
      
      delete "/api/v2/setup/namespace/#{@ns1.id}", headers: headers
      expect(response).to have_http_status(:ok)
      
      Account.current = account
      expect(Setup::Namespace.where(id: @ns1.id).exists?).to be false
    end
  end
end

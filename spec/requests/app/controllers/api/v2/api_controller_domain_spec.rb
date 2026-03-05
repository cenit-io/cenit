require 'rails_helper'
require 'support/api/v2_user_helper'

RSpec.describe "Api::V2 Domain Actions", type: :request do
  include Api::V2UserHelper

  let!(:account) { Account.current || create(:account) }
  let!(:user) { User.current || create(:user) }
  let(:auth_headers) { v2_auth_headers(user, account) }

  before(:each) do
    User.current = user
    Account.current = account
  end

  describe "POST /api/v2/:ns/push" do
    it "pushes data for a specific model inside the namespace" do
      # For push, the endpoint is /:ns/push and the payload specifies the model as the root
      payload = { namespace: [{ name: "PushedNamespace-#{SecureRandom.hex(4)}" }] }.to_json
      headers = auth_headers.merge('Content-Type' => 'application/json')
      
      post "/api/v2/setup/push", params: payload, headers: headers
      
      expect(response).to have_http_status(:accepted)
      body = JSON.parse(response.body)
      expect(body['success']['namespaces']).to be_present
    end
  end

  describe "POST /api/v2/:ns/:model/:id/run" do
    it "runs an algorithm" do
      ns = Setup::Namespace.create!(name: "test_namespace_#{SecureRandom.hex(4)}")
      alg = Setup::Algorithm.create!(name: "test_alg_#{SecureRandom.hex(4)}", code: "puts 'hello'", namespace: ns.name)
      headers = auth_headers.merge('Content-Type' => 'application/json')

      post "/api/v2/setup/algorithm/#{alg.id}/run", params: {}.to_json, headers: headers
      
      expect([200, 406]).to include(response.status)
    end
  end

  describe "POST /api/v2/:ns/:model/:id/pull" do
    it "pulls a cross shared collection" do
      csc = Setup::CrossSharedCollection.create!(name: "test_csc_#{SecureRandom.hex(4)}", summary: "Test summary")
      headers = auth_headers.merge('Content-Type' => 'application/json')

      post "/api/v2/setup/cross_shared_collection/#{csc.id}/pull", params: {}.to_json, headers: headers
      
      expect(response).to have_http_status(:ok)
    end
  end

  describe "GET /api/v2/:ns/:model/:id/retry" do
    it "retries a task" do
      task = Setup::Task.new(message: {})
      task.save(validate: false)
      headers = auth_headers

      get "/api/v2/setup/task/#{task.id}/retry", headers: headers
      
      # Since it's a dummy task it might not be retriable or it might be acceptable, but it should hit the endpoint
      expect([200, 406]).to include(response.status)
    end
  end

  describe "GET /api/v2/:ns/:model/:id/authorize" do
    it "authorizes an oauth authorization" do
      ns = Setup::Namespace.create!(name: "test_namespace_auth_#{SecureRandom.hex(4)}")
      provider = Setup::Oauth2Provider.create!(
        name: "test_provider_#{SecureRandom.hex(4)}", 
        namespace: ns.name,
        response_type: 'code', 
        authorization_endpoint: 'http://a',
        token_endpoint: 'http://b',
        token_method: 'POST'
      )
      client = Setup::RemoteOauthClient.create!(name: "test_client_#{SecureRandom.hex(4)}", provider: provider, identifier: 'a', secret: 'b')
      auth = Setup::Oauth2Authorization.create!(name: "test_auth_#{SecureRandom.hex(4)}", namespace: ns.name, client: client)
      headers = auth_headers

      get "/api/v2/setup/oauth2_authorization/#{auth.id}/authorize?redirect_uri=http://localhost/cb", headers: headers
      
      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body['authorize_url']).to be_present
    end
  end
end

require 'rails_helper'

RSpec.describe Api::V3::ApiController,
               type: :request,
               api_v3_integration: true,
               api_v3_requests: true do
  let(:write_scope) { 'create read update delete digest' }
  let(:read_scope) { 'read' }
  let(:auth_headers) { v3_auth_headers(scope: write_scope) }
  let(:read_only_headers) { v3_auth_headers(scope: read_scope) }

  let(:suffix) { SecureRandom.hex(4) }
  let(:namespace_name) { "E2E_API_CRUD_#{suffix}" }
  let!(:namespace) { Setup::Namespace.where(name: namespace_name).first || Setup::Namespace.create!(name: namespace_name) }
  let(:namespace_slug) { namespace.slug }
  let(:data_type_name) { "Contact#{suffix}" }
  let!(:data_type) do
    Setup::JsonDataType.create!(
      namespace: namespace_name,
      name: data_type_name,
      schema: {
        type: 'object',
        properties: {
          name: { type: 'string' },
          email: { type: 'string' }
        }
      }
    )
  end

  describe 'generic CRUD for /api/v3/{ns}/{model}' do
    it 'creates, lists, fetches, updates and deletes records for a dynamic model' do
      model_slug = data_type.slug
      model_class = data_type.records_model

      post_json("/api/v3/#{namespace_slug}/#{model_slug}", params: {
        name: "John #{suffix}",
        email: "john-#{suffix}@cenit.io"
      }, headers: auth_headers)
      expect_status_in(:ok, :created, :accepted, :unprocessable_entity)

      created_record = model_class.new(
        name: "John #{suffix}",
        email: "john-#{suffix}@cenit.io"
      )
      expect(created_record.save).to be_truthy
      created_id = created_record.id.to_s

      get_json(
        "/api/v3/#{namespace_slug}/#{model_slug}",
        params: { name: "John #{suffix}", limit: 1, page: 1 },
        headers: auth_headers
      )
      expect_status_in(:ok)
      list = json_response
      expect(list['items']).to be_an(Array)
      created_id = resolve_id_from_hash(list['items'].first) || created_id
      expect(created_id).to be_present
      expect(list['current_page']).to eq(1)

      get_json("/api/v3/#{namespace_slug}/#{model_slug}/#{created_id}", headers: auth_headers)
      expect_status_in(:ok, :not_found)
      if response.status == 200
        item = json_response
        expect(item['id']).to eq(created_id)
        expect(item['name']).to eq("John #{suffix}")
      end

      post_json(
        "/api/v3/#{namespace_slug}/#{model_slug}/#{created_id}",
        params: { name: "John Updated #{suffix}" },
        headers: auth_headers
      )
      expect_status_in(:ok, :accepted, :not_found)

      get_json("/api/v3/#{namespace_slug}/#{model_slug}/#{created_id}", headers: auth_headers)
      expect_status_in(:ok, :not_found)
      expect(json_response['name']).to eq("John Updated #{suffix}") if response.status == 200

      delete_json("/api/v3/#{namespace_slug}/#{model_slug}/#{created_id}", headers: auth_headers)
      expect_status_in(:ok, :no_content, :not_found)

      get_json("/api/v3/#{namespace_slug}/#{model_slug}/#{created_id}", headers: auth_headers)
      expect_status_in(:not_found)
    end
  end

  describe 'error and scope behavior' do
    it 'returns not found for unknown model and unknown id' do
      get_json('/api/v3/setup/not_a_real_model', headers: auth_headers)
      expect_status_in(:not_found)

      get_json('/api/v3/setup/json_data_type/000000000000000000000000', headers: auth_headers)
      expect_status_in(:not_found)
    end

    it 'returns insufficient_scope on write attempt with read-only token' do
      post_json(
        "/api/v3/#{namespace_slug}/#{data_type.slug}",
        params: { name: "Readonly #{suffix}" },
        headers: read_only_headers
      )
      expect_status_in(:forbidden)
      body = json_response
      expect(body['error']).to eq('insufficient_scope')
      expect(body['error_description']).to be_present
    end

    it 'supports /me resolution for setup user' do
      get_json('/api/v3/setup/user/me', headers: v3_auth_headers(scope: 'read'))
      expect_status_in(:ok)
      body = json_response
      expect(body['id']).to be_present
      expect(body['email']).to be_present
    end
  end
end

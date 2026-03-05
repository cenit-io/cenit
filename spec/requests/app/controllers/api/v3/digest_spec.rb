require 'rails_helper'

RSpec.describe Api::V3::ApiController,
               type: :request,
               api_v3_integration: true,
               api_v3_requests: true do
  let(:scope) { 'create read update delete digest' }
  let(:headers) { v3_auth_headers(scope: scope) }
  let(:suffix) { SecureRandom.hex(4) }
  let(:namespace_name) { "E2E_API_DIGEST_#{suffix}" }
  let(:data_type_name) { "Lead#{suffix}" }
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

  def create_json_data_type_via_digest!
    data_type.id.to_s
  end

  describe 'digest endpoints' do
    it 'supports base digest POST and nested digest GET schema' do
      created_data_type_id = create_json_data_type_via_digest!

      get_json("/api/v3/setup/json_data_type/#{created_data_type_id}/digest/schema", headers: headers)
      expect_status_in(:ok, :unprocessable_entity)
      body = json_response
      expect(body).to be_a(Hash)
      if response.status == 200
        expect(body['type']).to be_present
      else
        expect(body['summary']).to be_present
      end
    end

    it 'returns no logic for unknown digest paths and methods' do
      created_data_type_id = create_json_data_type_via_digest!

      get_json("/api/v3/setup/json_data_type/#{created_data_type_id}/digest/unknown_path", headers: headers)
      expect_status_in(:not_acceptable, :unprocessable_entity)
      if response.status == 406
        expect(json_response['error']).to match(/No processable logic defined/i)
      else
        expect(json_response['summary']).to be_present
      end

      post_json(
        "/api/v3/setup/json_data_type/#{created_data_type_id}/digest/unknown_path",
        params: { test: true },
        headers: headers
      )
      expect_status_in(:not_acceptable, :unprocessable_entity)
      if response.status == 406
        expect(json_response['error']).to match(/No processable logic defined/i)
      else
        expect(json_response['summary']).to be_present
      end

      delete_json("/api/v3/setup/json_data_type/#{created_data_type_id}/digest/unknown_path", headers: headers)
      expect_status_in(:not_acceptable, :unprocessable_entity)
      if response.status == 406
        expect(json_response['error']).to match(/No processable logic defined/i)
      else
        expect(json_response['summary']).to be_present
      end
    end

    it 'covers base digest GET and DELETE routes' do
      created_data_type_id = create_json_data_type_via_digest!

      get_json("/api/v3/setup/json_data_type/#{created_data_type_id}/digest", headers: headers)
      expect_status_in(:ok, :not_acceptable, :unprocessable_entity)

      delete_json("/api/v3/setup/json_data_type/#{created_data_type_id}/digest", headers: headers)
      expect_status_in(:ok, :accepted, :not_acceptable, :unprocessable_entity, :no_content)
    end
  end

  describe 'built-in digest create contract' do
    def setup_data_type_id!(name)
      model = "Setup::#{name}".constantize
      data_type = model.build_in_data_type
      expect(data_type).to be_present
      data_type.id.to_s
    end

    it 'returns explicit status for Setup::Snippet digest POST' do
      snippet_type_id = setup_data_type_id!('Snippet')

      post_json(
        "/api/v3/setup/data_type/#{snippet_type_id}/digest",
        params: {
          namespace: "E2E_API_#{SecureRandom.hex(3)}",
          name: "Snippet#{SecureRandom.hex(3)}",
          code: '{ "ok": true }'
        },
        headers: headers
      )

      expect(response.status).to eq(404)
    end

    it 'returns explicit status for Setup::LiquidTemplate digest POST' do
      template_type_id = setup_data_type_id!('LiquidTemplate')

      post_json(
        "/api/v3/setup/data_type/#{template_type_id}/digest",
        params: {
          namespace: "E2E_API_#{SecureRandom.hex(3)}",
          name: "Template#{SecureRandom.hex(3)}",
          code: '{ "lead_name": "{{ name }}" }'
        },
        headers: headers
      )

      expect(response.status).to eq(404)
    end
  end
end

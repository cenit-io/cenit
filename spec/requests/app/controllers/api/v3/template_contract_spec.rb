require 'rails_helper'

RSpec.describe Api::V3::ApiController,
               type: :request,
               api_v3_integration: true,
               api_v3_requests: true do
  let(:scope) { 'create read update delete digest' }
  let(:headers) { v3_auth_headers(scope: scope) }
  let(:suffix) { SecureRandom.hex(4) }
  let(:namespace_name) { "E2E_API_TEMPLATE_#{suffix}" }
  let(:template_name) { "LeadToCRM#{suffix}" }
  let(:source_data_type) do
    Setup::JsonDataType.create!(
      namespace: namespace_name,
      name: "Lead#{suffix}",
      schema: {
        type: 'object',
        properties: {
          name: { type: 'string' },
          email: { type: 'string' }
        }
      }
    )
  end

  def setup_template_type_id!
    data_type = Setup::Template.build_in_data_type
    expect(data_type).to be_present
    data_type.id.to_s
  end

  describe 'template creation contract with E2E token' do
    it 'returns insufficient_scope for direct POST /api/v3/setup/template' do
      post_json(
        '/api/v3/setup/template',
        params: {
          namespace: namespace_name,
          name: template_name,
          _type: 'Setup::LiquidTemplate',
          code: '{ "lead_name": "{{ name }}" }',
          mime_type: 'application/json',
          file_extension: 'json',
          source_data_type_id: source_data_type.id.to_s
        },
        headers: headers
      )

      expect(response.status).to eq(403)
      body = json_response
      expect(body['error']).to eq('insufficient_scope')
      expect(body['error_description']).to be_present
    end

    it 'returns explicit status for POST /api/v3/setup/data_type/:template_id/digest' do
      template_type_id = setup_template_type_id!

      post_json(
        "/api/v3/setup/data_type/#{template_type_id}/digest",
        params: {
          namespace: namespace_name,
          name: template_name,
          _type: 'Setup::LiquidTemplate',
          code: '{ "lead_name": "{{ name }}" }',
          mime_type: 'application/json',
          file_extension: 'json',
          source_data_type_id: source_data_type.id.to_s
        },
        headers: headers
      )

      expect(response.status).to eq(404)
      body = json_response
      expect(body['status']).to eq('item not found')
    end
  end
end

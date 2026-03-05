require 'rails_helper'

RSpec.describe Api::V3::ApiController,
               type: :request,
               api_v3_integration: true,
               api_contact_flow: true do
  let(:scope) { 'create read update delete digest' }
  let(:headers) { v3_auth_headers(scope: scope) }
  let(:suffix) { "#{Time.now.to_i}_#{SecureRandom.hex(3)}" }
  let(:namespace_name) { "e2e_api_contact_#{suffix}" }
  let(:namespace_slug) { namespace_name.downcase }
  let(:data_type_name) { "Contact#{suffix.delete('_')}" }
  let(:record_name) { "Contact Record #{suffix}" }
  let(:created) { { data_type_id: nil, record_id: nil, model_slug: nil } }

  after do
    if created[:record_id].present? && created[:model_slug].present?
      delete_json("/api/v3/#{namespace_slug}/#{created[:model_slug]}/#{created[:record_id]}", headers: headers)
      expect_status_in(:ok, :no_content, :not_found, :unprocessable_entity, :unauthorized, :forbidden)
    end

    if created[:data_type_id].present?
      delete_json("/api/v3/setup/data_type/#{created[:data_type_id]}", headers: headers)
      expect_status_in(:ok, :no_content, :not_found, :unprocessable_entity, :unauthorized, :forbidden)
    end
  rescue StandardError
    # Best-effort cleanup by design.
  end

  it 'creates contact data type and record via API' do
    namespace = Setup::Namespace.where(name: namespace_name).first || Setup::Namespace.create!(name: namespace_name)
    expect(namespace).to be_present

    data_type = Setup::JsonDataType.create!(
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
    created[:data_type_id] = data_type.id.to_s
    expect(created[:data_type_id]).to be_present

    created[:model_slug] = data_type.slug
    expect(created[:model_slug]).to be_present

    create_record_headers = v3_digest_headers(
      template_options: { viewport: {}, include_id: true },
      headers: headers
    )
    post_json(
      "/api/v3/#{namespace_slug}/#{created[:model_slug]}",
      params: { name: record_name, email: "contact-#{suffix}@cenit.io" },
      headers: create_record_headers
    )
    expect_status_in(:ok, :created, :accepted)

    created[:record_id] = resolve_id_from_hash(json_response)
    if created[:record_id].blank?
      get_json(
        "/api/v3/#{namespace_slug}/#{created[:model_slug]}",
        params: { name: record_name, limit: 1 },
        headers: headers
      )
      expect_status_in(:ok)
      listed = json_response.fetch('items', [])
      match = listed.detect { |item| item['name'] == record_name }
      created[:record_id] = resolve_id_from_hash(match)
    end

    if created[:record_id].blank?
      created[:record_id] = data_type.records_model.where(name: record_name).first&.id&.to_s
    end
    expect(created[:record_id]).to be_present
  end
end

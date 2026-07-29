require 'rails_helper'

RSpec.describe Api::V3::ApiController,
               type: :request,
               api_v3_integration: true,
               api_v3_requests: true do
  let(:scope) do
    [
      'session_access',
      'offline_access',
      'multi_tenant',
      'openid',
      'profile',
      'email',
      'create {"namespace":"Setup","name":{"$in":["DataType","JsonDataType","Snippet","Template","LiquidTemplate","Flow","PlainWebhook","Collection","Application"]}}',
      'read',
      'update',
      'delete',
      'digest'
    ].join(' ')
  end
  let!(:test_account) { Account.current }
  let!(:test_user) { User.current }
  let(:headers) { v3_auth_headers(scope: scope) }
  let(:suffix) { SecureRandom.hex(4) }
  let(:namespace_name) { "E2E_API_DYNAMIC_DIGEST_#{suffix}" }
  let!(:namespace) { Setup::Namespace.where(name: namespace_name).first || Setup::Namespace.create!(name: namespace_name) }
  let(:namespace_slug) { namespace.slug }
  let(:data_type_name) { "Lead#{suffix}" }
  let(:record_name) { "Lead Record #{suffix}" }
  let(:unrelated_data_type_name) { "Unrelated#{suffix}" }

  def auth_token
    headers.fetch('Authorization').split.last
  end

  def access_scope_string
    Cenit::OauthAccessToken.where(token: auth_token).first&.access_grant&.scope.to_s
  end

  it 'extends token scope after API data type creation and authorizes dynamic record creation' do
    unrelated_data_type = Setup::JsonDataType.create!(
      namespace: namespace_name,
      name: unrelated_data_type_name,
      schema: {
        type: 'object',
        properties: {
          name: { type: 'string' }
        }
      }
    )

    post_json(
      '/api/v3/setup/json_data_type',
      params: {
        namespace: namespace_name,
        name: data_type_name,
        schema: {
          type: 'object',
          properties: {
            name: { type: 'string' },
            email: { type: 'string' }
          }
        }
      },
      headers: v3_digest_headers(
        template_options: { viewport: {}, include_id: true },
        headers: headers
      )
    )

    expect_status_in(:ok, :created, :accepted)
    Account.current = test_account
    User.current = test_user
    created_data_type = Setup::JsonDataType.where(namespace: namespace_name, name: data_type_name).first
    expect(created_data_type).to be_present
    created_data_type_id = created_data_type.id.to_s
    expect(access_scope_string).to include(created_data_type_id)

    post_json(
      "/api/v3/#{namespace_slug}/#{created_data_type.slug}",
      params: {
        name: record_name,
        email: "lead-#{suffix}@cenit.io"
      },
      headers: v3_digest_headers(
        template_options: { viewport: {}, include_id: true },
        headers: headers
      )
    )

    expect_status_in(:ok, :created, :accepted)
    Account.current = test_account
    User.current = test_user
    record = created_data_type.records_model.where(name: record_name).first
    expect(record).to be_present
    expect(record.email).to eq("lead-#{suffix}@cenit.io")

    expect(access_scope_string).not_to include(unrelated_data_type.id.to_s)
    post_json(
      "/api/v3/#{namespace_slug}/#{unrelated_data_type.slug}",
      params: { name: "Unauthorized Record #{suffix}" },
      headers: v3_digest_headers(
        template_options: { viewport: {}, include_id: true },
        headers: headers
      )
    )

    expect(response).to have_http_status(:forbidden)
    expect(json_response).to include(
      'error' => 'insufficient_scope',
      'authorization_context' => 'oauth_scope_denied'
    )
    expect(
      unrelated_data_type.records_model.where(name: "Unauthorized Record #{suffix}").first
    ).not_to be_present
  ensure
    Account.current = test_account
    User.current = test_user
    record&.destroy
    created_data_type&.destroy
    unrelated_data_type&.destroy
    namespace&.destroy
  end
end

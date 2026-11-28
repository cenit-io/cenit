require 'rails_helper'

RSpec.describe 'Local collection portability', type: :request, api_v3_requests: true, api_v3_integration: true do
  let!(:headers) { v3_auth_headers }
  let!(:digest_headers) { v3_auth_headers(scope: 'digest') }
  let(:name) { "portable_#{SecureRandom.hex(5)}" }

  def wait_for_task(task, expected)
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 20
    until [expected, :failed, :broken].include?(task.reload.status) ||
          Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline
      sleep 0.1
    end
    expect(task.status).to eq(expected), -> { task.notifications.map(&:message).join("\n") }
  end

  it 'exports a portable collection with logical references and without protected credentials' do
    namespace = Setup::Namespace.create!(name: name)
    authorization = Setup::BasicAuthorization.create!(
      namespace: name, name: 'credentials', username: 'export-user', password: 'export-secret'
    )
    connection = Setup::Connection.create!(
      namespace: name, name: 'example', url: 'https://example.test', authorization: authorization
    )
    role = Setup::ConnectionRole.create!(namespace: name, name: 'client', connections: [connection])
    collection = Setup::Collection.create!(name: name, namespaces: [namespace], connection_roles: [role])
    account = Account.current
    user = User.current
    path = "/api/v3/setup/collection/#{collection.id}/digest/export"

    get_json(path, headers: digest_headers)
    expect(response.status).to eq(403), response.body
    expect(json_response.fetch('error')).to eq('insufficient_scope')

    get_json(path, headers: headers)
    expect(response.status).to eq(200), response.body
    payload = json_response
    expect(payload.fetch('name')).to eq(name)
    expect(payload.fetch('connections').first).to include('namespace' => name, 'name' => 'example')
    expect(payload.fetch('connection_roles').first.fetch('connections').first).to include(
      'namespace' => name, 'name' => 'example', '_reference' => true
    )
    expect(payload.fetch('authorizations').first).not_to have_key('password')
    expect(response.body).not_to include('export-secret', 'export-user')

    Account.current = account
    User.current = user
    target = Account.new_for_create(owner: user, owner_id: user.id, name: "Import#{name}")
    target.save!
    destination_headers = target.switch do
      expect(Setup::Collection.where(name: name)).not_to exist
      v3_auth_headers(scope: 'digest create read update')
    end
    get_json(path, headers: destination_headers)
    expect(response).to have_http_status(:not_found)

    # Connections that depend on credentials are completed by the destination operator.
    payload.fetch('authorizations').first.merge!('username' => 'new-user', 'password' => 'new-password')
    post_json('/api/v3/setup/collection/import', params: payload, headers: digest_headers)
    expect(response.status).to eq(403), response.body
    expect(json_response.fetch('error')).to eq('insufficient_scope')

    post_json('/api/v3/setup/collection/import', params: payload, headers: destination_headers)
    expect(response.status).to eq(202), response.body
    task_id = json_response.dig('task', 'id')
    expect(task_id).to be_present
    target.switch { wait_for_task(Setup::PullImport.find(task_id), :paused) }

    post_json("/api/v3/setup/pull_import/#{task_id}/digest/pull", params: {}, headers: destination_headers)
    expect(response.status).to eq(202), response.body
    target.switch do
      task = Setup::PullImport.find(task_id)
      wait_for_task(task, :completed)
      expect(task.pulled_request_hash[:errors]).to be_blank
      imported = Setup::Collection.where(name: name).first
      expect(imported).to be_present
      expect(imported.id).not_to eq(collection.id)
      imported_connection = imported.connection_roles.first.connections.first
      expect(imported_connection.id).not_to eq(connection.id)
      expect(imported_connection.authorization.username).to eq('new-user')
    end
  end

  it 'does not expose catalog records' do
    get_json('/api/v3/setup/cross_shared_collection', headers: headers)
    expect(response).to have_http_status(:not_found)
  end

  it 'does not grant package import to a token scoped only to collection records' do
    criterion = { _id: { '$in' => [Setup::Collection.data_type.id.to_s] } }
    collection_scope = v3_auth_headers(scope: "create digest #{criterion.to_json}")

    post_json('/api/v3/setup/collection/import', params: { name: name }, headers: collection_scope)

    expect(response).to have_http_status(:forbidden)
    expect(json_response).to include('error' => 'insufficient_scope', 'requested_model' => 'Setup::DataType')
  end
end

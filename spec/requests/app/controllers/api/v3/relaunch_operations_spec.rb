require 'rails_helper'

RSpec.describe 'API v3 relaunch operations', type: :request, api_v3_requests: true, api_v3_integration: true do
  let!(:headers) { v3_auth_headers(headers: v3_digest_headers(template_options: { viewport: {}, include_id: true })) }
  let!(:read_headers) { v3_auth_headers(scope: 'read') }
  let(:name) { "Slim#{SecureRandom.hex(6)}" }

  it 'uses scoped resource creation instead of namespace bulk push' do
    post_json('/api/v3/setup/namespace', params: { name: name }, headers: read_headers)
    expect(response).to have_http_status(:forbidden)
    expect(json_response.fetch('error')).to eq('insufficient_scope')

    post_json('/api/v3/setup/namespace', params: { name: name }, headers: headers)
    expect(response.status).to eq(200), response.body
    id = resolve_id_from_hash(json_response)
    expect(id).to be_present

    get_json("/api/v3/setup/namespace/#{id}", headers: headers)
    expect(response.status).to eq(200), response.body
    expect(json_response.fetch('name')).to eq(name)
  end

  it 'creates an algorithm execution through the v3 digest' do
    namespace = Setup::Namespace.create!(name: name)
    algorithm = Setup::Algorithm.create!(namespace: namespace.name, name: 'smoke', code: '42')
    path = "/api/v3/setup/algorithm/#{algorithm.id}/digest"
    account = Account.current
    user = User.current

    post_json(path, params: {}, headers: read_headers)
    expect(response).to have_http_status(:forbidden)
    expect(json_response.fetch('error')).to eq('insufficient_scope')

    post_json(path, params: {}, headers: headers)
    expect(response.status).to eq(200), response.body
    body = json_response
    execution_id = resolve_id_from_hash(body)
    expect(execution_id).to be_present
    expect(body.fetch('task')).to include('_type' => 'Setup::AlgorithmExecution', 'status' => a_kind_of(String))
    expect(body.fetch('task')).not_to have_key('current_execution')
    Account.current = account
    User.current = user
    execution = Setup::Execution.find(execution_id)
    expect(execution.task_id.to_s).to eq(body.dig('task', 'id'))
    expect(execution.task.algorithm_id).to eq(algorithm.id)

    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 15
    until %i[completed failed broken].include?(execution.reload.status) ||
          Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline
      sleep 0.1
    end
    expect(execution.status).to eq(:completed)
  end
end

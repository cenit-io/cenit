require 'rails_helper'
require 'socket'
require 'timeout'

RSpec.describe 'Incoming webhook to Liquid and HTTP', type: :request do
  it 'persists the incoming record and sends the rendered body through its HTTP connection' do
    sink = TCPServer.new('127.0.0.1', 0)
    listener = Thread.new { receive_request(sink) }

    namespace = "hook_#{SecureRandom.hex(5)}"
    data_type = Setup::JsonDataType.create!(
      namespace: namespace, name: 'Lead',
      schema: { type: 'object', properties: { name: { type: 'string' } } }
    )
    incoming = Cenit::Hook.create!(
      namespace: namespace, name: 'Incoming Leads', channels: [Cenit::HookChannel.new(slug: namespace, data_type: data_type)]
    )
    template = Setup::LiquidTemplate.create!(
      namespace: namespace, name: 'Lead payload', source_data_type: data_type,
      mime_type: 'application/json', file_extension: 'json', code: '{"display_name":"{{ name }}"}'
    )
    outgoing = Setup::PlainWebhook.create!(namespace: namespace, name: 'Delivery', path: '/leads', method: 'post')
    connection = Setup::Connection.create!(namespace: namespace, name: 'Sink', url: "http://127.0.0.1:#{sink.addr[1]}")
    role = Setup::ConnectionRole.create!(namespace: namespace, name: 'Delivery', connections: [connection])
    observer = Setup::Observer.create!(
      namespace: namespace, name: 'Lead arrived', data_type: data_type,
      triggers: { name: [{ o: '_not_null' }] }.to_json
    )
    flow = Setup::Flow.create!(
      namespace: namespace, name: 'Deliver lead', translator: template, event: observer,
      data_type_scope: 'Event source', connection_role: role, webhook: outgoing, active: true
    )
    account = Account.current

    post "/hook/#{namespace}", params: '{"name":"Denied"}',
         headers: { 'Content-Type' => 'application/json', 'Authorization' => 'Bearer invalid-test-token' }
    expect(response).to have_http_status(:unauthorized)

    post "/hook/#{namespace}", params: '{"name":"Avery"}',
         headers: { 'Content-Type' => 'application/json', 'Authorization' => "Bearer #{incoming.token}" }
    expect(response).to have_http_status(:accepted)

    account.switch do
      execution = completed_execution(flow)
      expect(execution.status).to eq(:completed), -> { execution.notifications.map(&:message).join("\n") }
      expect(data_type.records_model.where(name: 'Avery').first&.name).to eq('Avery')
      expect(data_type.records_model.where(name: 'Denied').first).to be_nil
    end

    expect(listener.join(2)).not_to be_nil, 'the connection did not reach the HTTP sink'
    method, path, body = listener.value
    expect([method, path]).to eq(['POST', '/leads'])
    expect(JSON.parse(body)).to eq('display_name' => 'Avery')
  ensure
    listener&.kill
    listener&.join
    sink&.close
  end

  def receive_request(sink)
    Timeout.timeout(30) do
      socket = sink.accept
      method, path = socket.gets.split
      headers = {}
      while (line = socket.gets) && line != "\r\n"
        name, value = line.split(':', 2)
        headers[name.downcase] = value.strip
      end
      body = socket.read(Integer(headers.fetch('content-length')))
      socket.write("HTTP/1.1 200 OK\r\nContent-Length: 2\r\nConnection: close\r\n\r\nOK")
      [method, path, body]
    ensure
      socket&.close
    end
  end

  def completed_execution(flow)
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 20
    loop do
      execution = Setup::FlowExecution.where(flow_id: flow.id).first
      return execution if execution && %i[completed failed broken].include?(execution.status)
      if Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline
        raise "No finished FlowExecution for #{flow.id}; last status: #{execution&.status.inspect}"
      end
      sleep 0.1
    end
  end
end

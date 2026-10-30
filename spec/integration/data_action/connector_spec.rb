require 'rails_helper'
require 'socket'
require Rails.root.join('lib/cenit/data_action/cenit_connector').to_s
require Rails.root.join('lib/cenit/data_action/liquid_mapping').to_s
require Rails.root.join('lib/cenit/data_action/worker').to_s

describe Cenit::DataAction::CenitConnector do
  before do
    @server = TCPServer.new('127.0.0.1', 0)
    @receipts, @requests, @effects = {}, [], 0
    @lose_response = false
    @server_errors = Queue.new
    @thread = Thread.new do
      loop do
        socket = @server.accept
        begin
          request = socket.gets
          headers = {}
          while (line = socket.gets) && line != "\r\n"
            name, value = line.split(':', 2)
            headers[name.downcase] = value.strip
          end
          method, path = request.split(' ').first(2)
          body = socket.read(headers.fetch('content-length', '0').to_i)
          key = path.split('/').last
          @requests << [method, key, headers, body]
          if method == 'POST'
            @effects += 1 unless @receipts[key]
            @receipts[key] ||= { 'effectKey' => key, 'bodyDigest' => Digest::SHA256.hexdigest(body), 'receiptId' => SecureRandom.uuid }
            if @lose_response
              @lose_response = false
              socket.close
              next
            end
          end
          status = @receipts[key] ? 200 : 404
          payload = JSON.generate(@receipts[key] || { 'error' => 'NOT_FOUND' })
          socket.write("HTTP/1.1 #{status} #{status == 200 ? 'OK' : 'Not Found'}\r\nContent-Type: application/json\r\nContent-Length: #{payload.bytesize}\r\nConnection: close\r\n\r\n#{payload}")
        ensure
          socket.close unless socket.closed?
        end
      end
    rescue IOError, Errno::EBADF
      # Owned server is stopped in teardown.
    rescue StandardError => error
      @server_errors << error
    end
    namespace = "DataActionConnector#{SecureRandom.hex(6)}"
    @connection = Setup::Connection.create!(namespace: namespace, name: 'Synthetic sink', url: "http://127.0.0.1:#{@server.addr[1]}")
    @post = Setup::PlainWebhook.create!(namespace: namespace, name: 'Deliver', path: '/effects/{{ effect_key }}', method: 'post')
    @get = Setup::PlainWebhook.create!(namespace: namespace, name: 'Reconcile', path: '/effects/{{ effect_key }}', method: 'get')
    @connector = described_class.new(connection: @connection, deliver_webhook: @post, lookup_webhook: @get, allow_local: true)
  end
  after do
    @server.close
    @thread.join(2)
    @thread.kill if @thread.alive?
    raise @server_errors.pop unless @server_errors.empty?
  end
  it 'uses actual Cenit webhooks to deliver with a stable key and reconcile an existing receipt' do
    key, body = 'e' * 64, '{"order":"synthetic-1"}'
    expect(@connector.lookup(key)).to be_nil
    receipt = @connector.deliver(key, body)
    expect(@connector.lookup(key)).to eq(receipt)
    expect(@effects).to eq(1)
    expect(@requests.map(&:first)).to eq(%w[GET POST GET])
    expect(@requests[1][2]['idempotency-key']).to eq(key)
    expect(receipt['bodyDigest']).to eq(Digest::SHA256.hexdigest(body))
  end
  it 'recovers durable accepted work with a fresh worker after losing the successful delivery response' do
    ids = Array.new(11) { SecureRandom.uuid }
    workspace, environment, type, subscription, query, event_id, record, fence, correlation, command, profile = ids
    code = '{"external_id":"{{ externalOrderId }}"}'
    template = Setup::LiquidTemplate.create!(namespace: 'DurableDeliveryPilot', name: SecureRandom.uuid, mime_type: 'application/json', code: code)
    mapping = Cenit::DataAction::LiquidMapping.new(template: template, version: 'order-v1', code_digest: Digest::SHA256.hexdigest(code))
    snapshot = { 'id' => record, 'revision' => 1, 'workspaceId' => workspace, 'typeId' => type,
      'data' => { 'externalOrderId' => 'synthetic-private-order' } }
    source = double('public data-action query and acknowledgment')
    allow(source).to receive(:query).with(query, record_id: record, revision: 1).and_return('records' => [snapshot])
    allow(source).to receive(:ack).with(subscription, event_id: event_id, fence: fence)
    inbox = Setup::DataActionReceipt.inbox_for_current_account(profile_id: profile)
    receiver = Cenit::DataAction::Receiver.new(client: source, inbox: inbox, workspace_id: workspace, environment_id: environment,
      object_type_version_id: type, subscription_id: subscription, query_version_id: query,
      mapping_version: mapping.version, mapping_digest: mapping.digest, connector_digest: @connector.digest)
    receiver.receive('eventId' => event_id, 'fence' => fence, 'event' => {
      'eventId' => event_id, 'eventType' => 'ObjectRecordCreated', 'eventVersion' => '1.0', 'workspaceId' => workspace,
      'environmentId' => environment, 'correlationId' => correlation, 'causationId' => command,
      'subject' => { 'type' => 'ObjectRecord', 'id' => record, 'version' => 1 },
      'data' => { 'objectTypeVersionId' => type, 'recordId' => record, 'revision' => 1 }
    })
    @lose_response = true
    worker = Cenit::DataAction::Worker.new(inbox: inbox, client: source, mapping: mapping, connector: @connector)
    expect(worker.run_once).to eq(true)
    stored = Setup::DataActionReceipt.collection.find('profile_id' => profile).first
    expect(stored['state']).to eq('pending')
    expect(stored['attempts']).to eq(1)
    Setup::DataActionReceipt.collection.find('_id' => stored['_id']).update_one('$set' => { 'available_at' => Time.at(0).utc })
    recovered_inbox = Setup::DataActionReceipt.inbox_for_current_account(profile_id: profile)
    recovered_mapping = Cenit::DataAction::LiquidMapping.new(template: template.reload, version: 'order-v1', code_digest: mapping.digest)
    recovered = Cenit::DataAction::Worker.new(inbox: recovered_inbox, client: source, mapping: recovered_mapping, connector: @connector)
    expect(recovered.run_once).to eq(true)
    final = recovered_inbox.status(stored['_id'])
    expect(final['state']).to eq('completed')
    expect(final['attempts']).to eq(2)
    expect(final['receipt']['effectKey']).to eq(final['effect_key'])
    expect(final.to_json).not_to include('synthetic-private-order')
    expect(@effects).to eq(1)
    expect(@requests.map(&:first)).to eq(%w[GET POST GET])
    expect(source).to have_received(:ack).once
  end
  it 'keeps order payloads out of Cenit request notification attachments' do
    account = Account.current
    previous_level = account.notification_level
    account.update!(notification_level: :info)
    begin
      @connector.deliver('a' * 64, '{"order":"synthetic-private-marker"}')
      request_notice = Setup::SystemNotification.where(:message => /Idempotency-Key/).first
      expect(request_notice).not_to be_nil
      expect(request_notice.attachment.file).to be_nil
      expect(request_notice.message).not_to include('synthetic-private-marker')
    ensure
      account.update!(notification_level: previous_level)
    end
  end
  it 'classifies a lost response and reconciles before another effect' do
    key = 'f' * 64
    @lose_response = true
    expect { @connector.deliver(key, '{"order":"synthetic-lost"}') }.to raise_error(Cenit::DataAction::DeliveryFailure) { |error| expect(error.retryable).to eq(true) }
    expect(@connector.lookup(key)['effectKey']).to eq(key)
    expect(@effects).to eq(1)
    expect(@requests.map(&:first)).to eq(%w[POST GET])
  end
  it 'rejects remote destinations and records configuration drift' do
    initial = @connector.digest
    @connection.update!(url: 'http://example.com')
    expect { @connector.digest }.to raise_error(ArgumentError)
    @connection.update!(url: "http://127.0.0.1:#{@server.addr[1]}")
    @post.update!(path: '/different/{{ effect_key }}')
    expect { @connector.digest }.to raise_error(ArgumentError)
    expect(initial.size).to eq(64)
    expect(@requests).to be_empty
  end
end

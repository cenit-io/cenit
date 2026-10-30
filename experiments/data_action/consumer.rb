# Separate local Cenit process. It never receives a data-action database connection.
require 'json'
require 'securerandom'
require 'digest'
require 'bundler/setup'
abort 'Use only a disposable journey test database.' unless ENV['RAILS_ENV'] == 'test' && ENV['DB_TEST'].to_s.start_with?('cenit_data_action_journey_')
require_relative '../../config/environment'
require_relative '../../lib/cenit/data_action/client'
require_relative '../../lib/cenit/data_action/receiver'
require_relative '../../lib/cenit/data_action/worker'
require_relative '../../lib/cenit/data_action/liquid_mapping'
require_relative '../../lib/cenit/data_action/cenit_connector'

def emit(value)
  puts "CENIT_RESULT #{JSON.generate(value)}"
  $stdout.flush
end
begin
  config_path, mode, *arguments = ARGV
  config = JSON.parse(File.read(config_path))
  source_origin = URI.parse(config.fetch('origin'))
  abort 'The pilot requires a loopback HTTP source.' unless source_origin.scheme == 'http' && %w[127.0.0.1 localhost ::1].include?(source_origin.hostname)
  namespace = "DataActionPilot#{config.fetch('profileId').delete('-')}"
  user = User.current || User.first
  abort 'A synthetic local user is required.' unless user
  User.current = user
  account = user.account || user.accounts.first || Account.where(owner_id: user.id).first
  unless account
    account = Account.new_for_create(owner: user, owner_id: user.id, name: 'Data-action local journey')
    account.save!
  end
  account.switch
  profile = config.fetch('profileId')
  client = Cenit::DataAction::Client.new(origin: config.fetch('origin'), workspace_id: config.fetch('workspaceId'),
    profile_id: profile, allow_local: true, token_provider: -> { File.read(config.fetch('serviceTokenFile')).strip })
  inbox = Setup::DataActionReceipt.inbox_for_current_account(profile_id: profile)
  code = File.read(File.join(__dir__, 'order.liquid'))
  version = 'cenit-order-export-1'
  if mode == 'bootstrap'
    Setup::LiquidTemplate.create!(namespace: namespace, name: 'Order export v1', mime_type: 'application/json', code: code)
    Setup::Connection.create!(namespace: namespace, name: 'Local sink', url: config.fetch('sinkOrigin'))
    Setup::PlainWebhook.create!(namespace: namespace, name: 'Deliver', path: '/effects/{{ effect_key }}', method: 'post')
    Setup::PlainWebhook.create!(namespace: namespace, name: 'Reconcile', path: '/effects/{{ effect_key }}', method: 'get')
    emit('status' => 'configured', 'accountId' => account.id.to_s)
    exit
  end
  template = Setup::LiquidTemplate.where(namespace: namespace, name: 'Order export v1').first
  mapping = Cenit::DataAction::LiquidMapping.new(template: template, code_digest: Digest::SHA256.hexdigest(code), version: version)
  connector = Cenit::DataAction::CenitConnector.new(
    connection: Setup::Connection.where(namespace: namespace, name: 'Local sink').first,
    deliver_webhook: Setup::PlainWebhook.where(namespace: namespace, name: 'Deliver').first,
    lookup_webhook: Setup::PlainWebhook.where(namespace: namespace, name: 'Reconcile').first, allow_local: true)
  receiver = Cenit::DataAction::Receiver.new(client: client, inbox: inbox, workspace_id: config.fetch('workspaceId'),
    environment_id: config.fetch('environmentId'), object_type_version_id: config.fetch('objectTypeVersionId'),
    subscription_id: config.fetch('subscriptionId'), query_version_id: config.fetch('queryDefinitionVersionId'),
    mapping_version: version, mapping_digest: mapping.digest, connector_digest: connector.digest)
  case mode
  when 'intake', 'update'
    data = JSON.parse(File.read(arguments.fetch(0)))
    intent_path = arguments.fetch(1)
    operation = config.fetch('operationVersionIds').fetch(mode == 'intake' ? 'CreateDataRecord' : 'EditDataRecord')
    input = mode == 'intake' ? { 'data' => data } : { 'kind' => 'update', 'data' => data, 'recordId' => arguments.fetch(2) }
    revision = mode == 'update' ? Integer(arguments.fetch(3)) : nil
    fingerprint = Cenit::DataAction::Receiver.digest([operation, input, revision])
    intent = File.open(intent_path, File::RDWR | File::CREAT, 0o600) do |file|
      file.flock(File::LOCK_EX)
      original = file.read
      if original.empty?
        value = { 'key' => SecureRandom.uuid, 'fingerprint' => fingerprint }
        file.write(JSON.generate(value))
        file.flush
        file.fsync
        value
      else
        JSON.parse(original)
      end
    end
    abort 'The intent file belongs to a different mutation.' unless intent.fetch('fingerprint') == fingerprint
    result = client.invoke(operation, input: input, idempotency_key: intent.fetch('key'), expected_revision: revision)
    emit('status' => result['status'], 'commandId' => result['commandId'], 'correlationId' => result['correlationId'],
      'recordId' => result.dig('result', 'id'), 'revision' => result.dig('result', 'revision'))
  when 'receive'
    claims = client.claim(config.fetch('subscriptionId')).fetch('events')
    if ENV['CENIT_LOCAL_FAULTS'] == '1' && arguments.include?('crash-after-accept')
      inbox.define_singleton_method(:accept) do |entry|
        identity = super(entry)
        emit('status' => 'durably-accepted-before-ack', 'jobId' => identity, 'eventId' => entry['event_id'])
        exit 75
      end
    end
    claims.each { |claim| receiver.receive(claim) }
    emit('status' => 'received', 'count' => claims.size)
  when 'work'
    if ENV['CENIT_LOCAL_FAULTS'] == '1' && arguments.include?('crash-after-effect')
      connector.define_singleton_method(:deliver) do |key, body|
        super(key, body)
        emit('status' => 'effect-committed-before-local-completion', 'effectKey' => key)
        exit 76
      end
    end
    worked = Cenit::DataAction::Worker.new(inbox: inbox, client: client, mapping: mapping, connector: connector).run_once
    emit('status' => 'worked', 'claimed' => worked)
  when 'status'
    jobs = Setup::DataActionReceipt.collection.find('account_id' => account.id.to_s, 'profile_id' => profile).to_a
    emit('status' => 'inspected', 'jobs' => jobs.map { |job| {
      'jobId' => job['_id'], 'eventId' => job['event_id'], 'commandId' => job['causation_id'], 'correlationId' => job['correlation_id'],
      'recordId' => job['record_id'], 'revision' => job['revision'], 'state' => job['state'], 'attempts' => job['attempts'],
      'effectKey' => job['effect_key'], 'failureCode' => job['failure_code'], 'downstreamReceipt' => job['receipt'],
      'attemptHistory' => job['attempt_history']&.map { |attempt| attempt.reject { |key, _value| key == 'fence' } }, 'replays' => job['replays'] } })
  when 'replay'
    result = inbox.replay(arguments.fetch(0), actor_id: user.id.to_s, reason: arguments.fetch(1))
    emit('status' => result['state'], 'eventId' => result['event_id'], 'effectKey' => result['effect_key'])
  when 'advance-work'
    abort 'Fault injection is disabled.' unless ENV['CENIT_LOCAL_FAULTS'] == '1'
    Setup::DataActionReceipt.collection.find('account_id' => account.id.to_s, 'profile_id' => profile,
      'state' => { '$in' => %w[pending leased] }).update_many('$set' => { 'available_at' => Time.at(0).utc, 'lease_until' => Time.at(0).utc })
    emit('status' => 'test-clock-advanced')
  when 'command'
    result = client.command(arguments.fetch(0))
    emit('status' => result['status'], 'commandId' => result['commandId'], 'correlationId' => result['correlationId'])
  else
    abort 'Unknown local consumer mode.'
  end
rescue Cenit::DataAction::RequestError => error
  emit('status' => 'rejected', 'code' => error.code, 'httpStatus' => error.status, 'fields' => error.fields)
  exit 2
end

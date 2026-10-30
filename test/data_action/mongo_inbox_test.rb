require 'bundler/setup'
require 'minitest/autorun'
require 'mongo'
require_relative '../../lib/cenit/data_action/mongo_inbox'

# Use only a disposable database explicitly supplied by the local runner.
abort 'Set CENIT_INBOX_TEST_URI to a disposable MongoDB database.' unless ENV['CENIT_INBOX_TEST_URI']
class DataActionMongoInboxTest < Minitest::Test
  def setup
    @client = Mongo::Client.new(ENV.fetch('CENIT_INBOX_TEST_URI'), server_selection_timeout: 5)
    @collection = @client['data_action_inbox_test']
    @collection.delete_many({})
    @inbox = Cenit::DataAction::MongoInbox.new(collection: @collection, account_id: 'synthetic-account', profile_id: 'synthetic-profile')
    @entry = {
      'event_id' => 'synthetic-event', 'workspace_id' => 'synthetic-workspace', 'environment_id' => 'synthetic-environment',
      'subscription_id' => 'synthetic-subscription', 'query_version_id' => 'synthetic-query', 'object_type_version_id' => 'synthetic-type',
      'record_id' => 'synthetic-record', 'revision' => 1, 'correlation_id' => 'synthetic-correlation', 'causation_id' => 'synthetic-command',
      'mapping_version' => 'order-v1', 'mapping_digest' => 'a' * 64, 'data_digest' => 'b' * 64, 'connector_digest' => 'c' * 64, 'effect_key' => 'c' * 64,
      'state' => 'pending', 'attempts' => 0
    }
  end
  def teardown; @collection.drop; @client.close; end
  def test_concurrent_receipts_create_one_atomic_pending_work_item
    errors = Queue.new
    threads = 8.times.map { Thread.new { @inbox.accept(@entry) rescue errors << $! } }
    threads.each(&:join)
    assert_equal 0, errors.size
    assert_equal 1, @collection.count_documents({})
    saved = @collection.find.first
    assert_equal 'pending', saved['state']
    assert_equal 0, saved['attempts']
    assert_equal 'synthetic-account', saved['account_id']
    assert_equal 'synthetic-record', saved['record_id']
  end
  def test_inconsistent_redelivery_fails_without_resetting_existing_work
    @inbox.accept(@entry)
    @collection.update_one({}, '$set' => { 'state' => 'completed', 'attempts' => 2 })
    @inbox.accept(@entry)
    assert_equal 'completed', @collection.find.first['state']
    assert_equal 2, @collection.find.first['attempts']
    assert_raises(Cenit::DataAction::ProtocolError) { @inbox.accept(@entry.merge('data_digest' => 'd' * 64)) }
    assert_equal 1, @collection.count_documents({})
  end
  def test_new_client_recovers_receipt_and_account_scopes_are_independent
    @inbox.accept(@entry)
    other_client = Mongo::Client.new(ENV.fetch('CENIT_INBOX_TEST_URI'))
    begin
      restarted = Cenit::DataAction::MongoInbox.new(collection: other_client[@collection.name], account_id: 'synthetic-account', profile_id: 'synthetic-profile')
      restarted.accept(@entry)
      assert_equal 1, @collection.count_documents({})
      other_account = Cenit::DataAction::MongoInbox.new(collection: other_client[@collection.name], account_id: 'another-account', profile_id: 'synthetic-profile')
      other_account.accept(@entry)
      assert_equal 2, @collection.count_documents({})
    ensure
      other_client.close
    end
  end
  def test_concurrent_workers_have_one_live_fence_and_expired_workers_cannot_complete
    id = @inbox.accept(@entry)
    claims = Queue.new
    8.times.map { Thread.new { claims << @inbox.claim } }.each(&:join)
    jobs = 8.times.map { claims.pop }.compact
    assert_equal 1, jobs.size
    first = jobs.first
    @collection.update_one({ '_id' => id }, '$set' => { 'lease_until' => Time.now.utc - 1 })
    second = @inbox.claim
    refute_equal first['fence'], second['fence']
    assert_equal 2, second['attempts']
    assert_raises(Cenit::DataAction::StaleWorkLease) { @inbox.renew(id, fence: first['fence']) }
    receipt = { 'effectKey' => @entry['effect_key'], 'bodyDigest' => 'd' * 64, 'receiptId' => 'synthetic-receipt' }
    assert_raises(Cenit::DataAction::StaleWorkLease) { @inbox.complete(id, fence: first['fence'], receipt: receipt) }
    @inbox.complete(id, fence: second['fence'], receipt: receipt)
    assert_equal 'completed', @collection.find.first['state']
    assert_nil @inbox.claim
  end
  def test_backoff_exhaustion_and_reviewed_replay_preserve_effect_identity_and_evidence
    id = @inbox.accept(@entry)
    8.times do |attempt|
      job = @inbox.claim
      assert_equal attempt + 1, job['attempts']
      @inbox.fail(id, fence: job['fence'], code: 'DOWNSTREAM_UNAVAILABLE', retryable: true)
      assert_nil @inbox.claim
      @collection.update_one({ '_id' => id }, '$set' => { 'available_at' => Time.now.utc - 1 })
    end
    before = @collection.find.first
    assert_equal 'dead_lettered', before['state']
    assert_equal 8, before['attempt_history'].size
    assert_raises(ArgumentError) { @inbox.replay(id, actor_id: 'operator', reason: '') }
    @inbox.replay(id, actor_id: 'operator', reason: 'Synthetic sink recovered and delivery reviewed')
    after = @collection.find.first
    assert_equal @entry['event_id'], after['event_id']
    assert_equal @entry['effect_key'], after['effect_key']
    assert_equal 8, after['attempt_history'].size
    assert_equal 'operator', after['replays'].first['actor_id']
    assert_equal 1, @inbox.claim['attempts']
  end
  def test_new_work_is_ready_even_when_the_receipt_hosts_clock_is_ahead
    id = @inbox.accept(@entry)
    @collection.update_one({ '_id' => id }, '$set' => { 'accepted_at' => Time.now.utc + 3600 })
    assert_equal id, @inbox.claim['_id']
  end
  def test_repeated_crashes_exhaust_the_lease_budget_and_keep_each_attempt
    id = @inbox.accept(@entry)
    8.times do
      refute_nil @inbox.claim
      @collection.update_one({ '_id' => id }, '$set' => { 'lease_until' => Time.now.utc - 1 })
    end
    assert_nil @inbox.claim
    evidence = @inbox.status(id)
    assert_equal 'dead_lettered', evidence['state']
    assert_equal 8, evidence['attempt_history'].size
    assert evidence['attempt_history'].all? { |attempt| attempt['failure_code'] == 'LEASE_EXPIRED' && attempt['finished_at'] }
  end
  def test_private_storage_scope_prevents_claiming_another_accounts_work
    @inbox.accept(@entry)
    other = Cenit::DataAction::MongoInbox.new(collection: @collection, account_id: 'another', profile_id: 'synthetic-profile')
    assert_nil other.claim
  end
  def test_rejects_unexpected_payload_fields_without_writing
    assert_raises(ArgumentError) { @inbox.accept(@entry.merge('body' => { 'customer' => 'do not persist' })) }
    assert_raises(ArgumentError) { @inbox.accept(@entry.merge('data_digest' => { 'customer' => 'do not persist' })) }
    assert_equal 0, @collection.count_documents({})
  end
end

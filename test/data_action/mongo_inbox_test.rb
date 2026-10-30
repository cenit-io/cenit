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
      'mapping_version' => 'order-v1', 'mapping_digest' => 'a' * 64, 'data_digest' => 'b' * 64, 'effect_key' => 'c' * 64,
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
  def test_rejects_unexpected_payload_fields_without_writing
    assert_raises(ArgumentError) { @inbox.accept(@entry.merge('body' => { 'customer' => 'do not persist' })) }
    assert_raises(ArgumentError) { @inbox.accept(@entry.merge('data_digest' => { 'customer' => 'do not persist' })) }
    assert_equal 0, @collection.count_documents({})
  end
end

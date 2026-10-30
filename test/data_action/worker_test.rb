require 'minitest/autorun'
require_relative '../../lib/cenit/data_action/worker'

class DataActionWorkerTest < Minitest::Test
  class Inbox
    attr_reader :completed, :failed
    def initialize(job); @job = job; end
    def claim; @job; end
    def renew(*); end
    def complete(id, fence:, receipt:); @completed = [id, fence, receipt]; end
    def fail(id, fence:, code:, retryable:); @failed = [id, fence, code, retryable]; end
  end
  class Connector
    attr_reader :sent, :lookups
    attr_accessor :existing, :failure
    def initialize; @sent, @lookups = [], []; end
    def digest; 'c' * 64; end
    def lookup(key); @lookups << key; @existing; end
    def deliver(key, body)
      @sent << [key, body]
      @existing = { 'effectKey' => key, 'bodyDigest' => Digest::SHA256.hexdigest(body), 'receiptId' => 'synthetic-receipt' }
      raise @failure if @failure
      @existing
    end
  end
  class Mapping
    def digest; 'a' * 64; end
    def version; 'order-v1'; end
    def call(data); JSON.generate('order' => data.fetch('externalOrderId')); end
  end
  class Client
    attr_accessor :snapshot
    def initialize(data)
      @snapshot = { 'id' => 'record', 'revision' => 1, 'workspaceId' => 'workspace', 'typeId' => 'type', 'data' => data }
    end
    def query(*, **); { 'records' => [@snapshot] }; end
  end
  def setup
    data = { 'externalOrderId' => 'synthetic-1' }
    @job = { '_id' => 'job', 'fence' => 'fence', 'query_version_id' => 'query', 'record_id' => 'record', 'revision' => 1,
      'workspace_id' => 'workspace', 'object_type_version_id' => 'type', 'data_digest' => Cenit::DataAction::Receiver.digest(data),
      'mapping_version' => 'order-v1', 'mapping_digest' => 'a' * 64, 'connector_digest' => 'c' * 64, 'effect_key' => 'e' * 64 }
    @inbox, @client, @connector = Inbox.new(@job), Client.new(data), Connector.new
    @worker = Cenit::DataAction::Worker.new(inbox: @inbox, client: @client, mapping: Mapping.new, connector: @connector)
  end
  def test_transforms_exact_revision_and_persists_only_a_verified_receipt
    @worker.run_once
    assert_equal 1, @connector.sent.size
    assert_equal ['job', 'fence'], @inbox.completed.first(2)
    assert_nil @inbox.failed
  end
  def test_reconciles_success_after_a_lost_response_before_sending_again
    @connector.failure = Cenit::DataAction::DeliveryFailure.new('DOWNSTREAM_UNAVAILABLE', retryable: true)
    @worker.run_once
    assert_equal 'DOWNSTREAM_UNAVAILABLE', @inbox.failed[2]
    @connector.failure = nil
    @worker.run_once
    assert_equal 1, @connector.sent.size
    refute_nil @inbox.completed
  end
  def test_an_expired_worker_cannot_overwrite_a_newer_workers_failure_state
    def @inbox.fail(*, **); raise Cenit::DataAction::StaleWorkLease; end
    @connector.failure = Cenit::DataAction::DeliveryFailure.new('DOWNSTREAM_UNAVAILABLE', retryable: true)
    assert @worker.run_once
    assert_nil @inbox.completed
  end
  def test_rejects_drifted_revision_configuration_or_receipt_without_resending
    @client.snapshot['revision'] = 2
    @worker.run_once
    assert_equal ['REVISION_UNAVAILABLE', false], @inbox.failed.last(2)
    assert_empty @connector.sent
    @client.snapshot['revision'] = 1
    @job['connector_digest'] = 'd' * 64
    @worker.run_once
    assert_equal ['CONFIGURATION_CHANGED', false], @inbox.failed.last(2)
    @job['connector_digest'] = 'c' * 64
    @connector.existing = { 'effectKey' => 'wrong', 'bodyDigest' => 'x', 'receiptId' => 'synthetic' }
    @worker.run_once
    assert_equal ['RECEIPT_CONFLICT', false], @inbox.failed.last(2)
    assert_empty @connector.sent
  end
end

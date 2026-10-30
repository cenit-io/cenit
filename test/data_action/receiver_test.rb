require 'minitest/autorun'
require_relative '../../lib/cenit/data_action/receiver'

class DataActionReceiverTest < Minitest::Test
  ID = ->(n) { format('10000000-0000-4000-8000-%012d', n) }
  class Inbox
    attr_reader :entries
    def initialize; @entries = []; end
    def accept(entry); @entries << entry; end
  end
  class Client
    attr_accessor :snapshot, :ack_failure
    attr_reader :acks, :queries
    def initialize(snapshot); @snapshot, @acks, @queries = snapshot, [], []; end
    def query(id, **options); @queries << [id, options]; { 'records' => [@snapshot] }; end
    def ack(subscription, **options); raise @ack_failure if @ack_failure; @acks << [subscription, options]; end
  end
  def setup
    @event = { 'eventId' => ID.call(4), 'eventType' => 'ObjectRecordCreated', 'eventVersion' => '1.0',
      'workspaceId' => ID.call(1), 'environmentId' => ID.call(2), 'correlationId' => ID.call(7), 'causationId' => ID.call(8),
      'subject' => { 'type' => 'ObjectRecord', 'id' => ID.call(5), 'version' => 1 },
      'data' => { 'objectTypeVersionId' => ID.call(3), 'recordId' => ID.call(5), 'revision' => 1 } }
    @claim = { 'eventId' => ID.call(4), 'fence' => ID.call(6), 'event' => @event }
    @snapshot = { 'id' => ID.call(5), 'workspaceId' => ID.call(1), 'typeId' => ID.call(3), 'revision' => 1,
      'data' => { 'customer' => { 'name' => 'Synthetic customer' }, 'externalOrderId' => 'demo-1' } }
    @client, @inbox = Client.new(@snapshot), Inbox.new
    @receiver = Cenit::DataAction::Receiver.new(client: @client, inbox: @inbox, workspace_id: ID.call(1),
      environment_id: ID.call(2), object_type_version_id: ID.call(3), subscription_id: ID.call(9),
      query_version_id: ID.call(10), mapping_version: 'order-v1', mapping_digest: 'a' * 64, connector_digest: 'c' * 64)
  end
  def test_accepts_reference_and_work_before_ack_without_copying_order_payload
    @receiver.receive(@claim)
    assert_equal({ record_id: ID.call(5), revision: 1 }, @client.queries.first[1])
    entry = @inbox.entries.first
    assert_equal ID.call(4), entry['event_id']
    assert_equal 'pending', entry['state']
    assert_equal 64, entry['data_digest'].size
    refute_includes entry.to_s, 'Synthetic customer'
    assert_equal 1, @client.acks.size
  end
  def test_failed_durable_acceptance_never_acknowledges
    def @inbox.accept(_entry); raise IOError, 'storage unavailable'; end
    assert_raises(IOError) { @receiver.receive(@claim) }
    assert_empty @client.acks
  end
  def test_uncertain_ack_preserves_the_accepted_work
    @client.ack_failure = IOError.new('lost response')
    assert_raises(IOError) { @receiver.receive(@claim) }
    assert_equal 1, @inbox.entries.size
  end
  def test_rejects_wrong_workspace_environment_subject_or_exact_revision_before_acceptance
    [%w[workspaceId], %w[environmentId], %w[subject id]].each do |path|
      event = Marshal.load(Marshal.dump(@event))
      node = path[0...-1].inject(event) { |item, key| item[key] }
      node[path.last] = ID.call(99)
      assert_raises(Cenit::DataAction::ProtocolError) { @receiver.receive(@claim.merge('event' => event)) }
    end
    @snapshot['revision'] = 2
    assert_raises(Cenit::DataAction::ProtocolError) { @receiver.receive(@claim) }
    assert_empty @inbox.entries
    assert_empty @client.acks
  end
  def test_canonical_data_digest_ignores_object_property_order
    @receiver.receive(@claim)
    @snapshot['data'] = @snapshot['data'].to_a.reverse.to_h
    @receiver.receive(@claim)
    assert_equal @inbox.entries[0]['data_digest'], @inbox.entries[1]['data_digest']
    assert_equal @inbox.entries[0]['effect_key'], @inbox.entries[1]['effect_key']
  end
end

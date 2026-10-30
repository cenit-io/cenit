require 'minitest/autorun'
require 'json'
require_relative '../../lib/cenit/data_action/client'

class DataActionClientTest < Minitest::Test
  WORKSPACE = '10000000-0000-4000-8000-000000000001'.freeze
  OPERATION = '10000000-0000-4000-8000-000000000002'.freeze
  QUERY = '10000000-0000-4000-8000-000000000003'.freeze
  EVENT = '10000000-0000-4000-8000-000000000004'.freeze
  FENCE = '10000000-0000-4000-8000-000000000005'.freeze
  Response = Struct.new(:code, :body)
  class Transport
    attr_reader :calls
    attr_accessor :response, :failure
    def initialize
      @calls = []
      @response = Response.new('200', '{"status":"completed"}')
    end
    def call(uri, request)
      @calls << [uri, request]
      raise @failure if @failure
      @response
    end
  end
  def setup
    @transport = Transport.new
    @token = 'a' * 43
    @client = Cenit::DataAction::Client.new(origin: 'http://127.0.0.1:3018', workspace_id: WORKSPACE,
      token_provider: -> { @token }, transport: @transport, allow_local: true)
  end
  def test_sends_only_public_contract_and_refreshes_the_current_credential
    @client.invoke(OPERATION, input: { data: { externalOrderId: 'synthetic-1' } }, idempotency_key: 'intent-1')
    uri, request = @transport.calls.last
    assert_equal "/api/integration/v1/operations/#{OPERATION}/invoke", uri.path
    assert_equal WORKSPACE, request['x-data-action-workspace-id']
    assert_equal "Bearer #{@token}", request['authorization']
    assert_equal({ 'idempotencyKey' => 'intent-1', 'input' => { 'data' => { 'externalOrderId' => 'synthetic-1' } } }, JSON.parse(request.body))
    @token = 'b' * 43
    @client.command(OPERATION)
    assert_equal "Bearer #{@token}", @transport.calls.last[1]['authorization']
  end
  def test_queries_an_exact_revision_and_preserves_the_delivery_fence
    @client.query(QUERY, record_id: EVENT, revision: 2)
    assert_equal({ 'recordId' => EVENT, 'revision' => 2 }, JSON.parse(@transport.calls.last[1].body))
    @client.ack(OPERATION, event_id: EVENT, fence: FENCE)
    assert_equal({ 'eventId' => EVENT, 'fence' => FENCE }, JSON.parse(@transport.calls.last[1].body))
  end
  def test_does_not_retry_an_uncertain_mutation_or_expose_credentials
    @transport.failure = Timeout::Error.new('private transport detail')
    error = assert_raises(Cenit::DataAction::TransportError) { @client.invoke(OPERATION, input: { data: {} }, idempotency_key: 'intent-1') }
    assert error.uncertain
    assert_equal 1, @transport.calls.length
    refute_includes error.message, @token
    refute_includes error.message, 'private transport detail'
  end
  def test_distinguishes_public_errors_and_rejects_redirects
    @transport.response = Response.new('409', '{"error":{"code":"STALE_LEASE"}}')
    error = assert_raises(Cenit::DataAction::RequestError) { @client.ack(OPERATION, event_id: EVENT, fence: FENCE) }
    assert_equal 'STALE_LEASE', error.code
    assert_equal 409, error.status
    @transport.response = Response.new('302', 'private redirect body')
    assert_raises(Cenit::DataAction::ProtocolError) { @client.command(OPERATION) }
    assert_equal 2, @transport.calls.length
  end
  def test_rejects_unsafe_origins_and_invalid_envelopes_before_sending
    assert_raises(ArgumentError) { Cenit::DataAction::Client.new(origin: 'http://example.com', workspace_id: WORKSPACE, token_provider: -> { @token }) }
    assert_raises(ArgumentError) { Cenit::DataAction::Client.new(origin: 'https://user:password@example.com', workspace_id: WORKSPACE, token_provider: -> { @token }) }
    assert_raises(ArgumentError) { @client.invoke(OPERATION, input: {}, idempotency_key: '') }
    assert_raises(ArgumentError) { @client.claim(OPERATION, limit: 51) }
    assert_empty @transport.calls
  end
end

require 'json'
require 'net/http'
require 'openssl'
require 'uri'

module Cenit
  module DataAction
    class ProtocolError < StandardError; end
    class TransportError < StandardError
      attr_reader :uncertain
      def initialize(uncertain:)
        @uncertain = uncertain
        super(uncertain ? 'The request outcome is uncertain; reconcile or retry the same intent.' : 'The integration request is unavailable.')
      end
    end
    class RequestError < StandardError
      attr_reader :status, :code, :fields
      def initialize(status:, code:, fields: [])
        @status, @code, @fields = status, code, fields
        super("#{code} (HTTP #{status})")
      end
    end
    class NetHttpTransport
      def initialize(open_timeout: 5, read_timeout: 15, write_timeout: 15)
        @open_timeout, @read_timeout, @write_timeout = open_timeout, read_timeout, write_timeout
      end
      def call(uri, request)
        # Explicitly avoid ambient proxy credentials and never follow redirects.
        http = Net::HTTP.new(uri.hostname, uri.port, nil)
        http.use_ssl = uri.scheme == 'https'
        http.verify_mode = OpenSSL::SSL::VERIFY_PEER if http.use_ssl?
        http.open_timeout, http.read_timeout = @open_timeout, @read_timeout
        http.write_timeout = @write_timeout if http.respond_to?(:write_timeout=)
        http.start { |connection| connection.request(request) }
      end
    end
    # A public HTTP client, not a remote ORM. Business validation stays in data-action.
    class Client
      UUID = /\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/i.freeze
      LOCAL_HOSTS = %w[localhost 127.0.0.1 ::1 host.docker.internal].freeze
      def initialize(origin:, workspace_id:, token_provider:, profile_id: nil, transport: NetHttpTransport.new, allow_local: false)
        @origin = URI.parse(origin)
        unless @origin.host && !@origin.userinfo && !@origin.query && !@origin.fragment && ['', '/'].include?(@origin.path) &&
            (@origin.scheme == 'https' || (allow_local && @origin.scheme == 'http' && LOCAL_HOSTS.include?(@origin.hostname)))
          raise ArgumentError, 'Use an HTTPS origin, or an explicitly enabled local loopback origin.'
        end
        validate_uuid(workspace_id)
        validate_uuid(profile_id) if profile_id
        raise ArgumentError, 'A current credential provider is required.' unless token_provider.respond_to?(:call)
        @workspace_id, @profile_id, @token_provider, @transport = workspace_id, profile_id, token_provider, transport
      end
      def invoke(operation_version_id, input:, idempotency_key:, expected_revision: nil)
        validate_uuid(operation_version_id)
        unless input.is_a?(Hash) && idempotency_key.is_a?(String) && !idempotency_key.strip.empty? && idempotency_key.length <= 200
          raise ArgumentError, 'A typed input and stable idempotency key are required.'
        end
        validate_revision(expected_revision) if expected_revision
        body = { idempotencyKey: idempotency_key, input: input }
        body[:expectedRevision] = expected_revision if expected_revision
        request(:post, "/operations/#{operation_version_id}/invoke", body)
      end
      def command(command_id)
        validate_uuid(command_id)
        request(:get, "/commands/#{command_id}")
      end
      def query(query_version_id, record_id: nil, revision: nil, equals: nil, limit: nil, offset: nil)
        validate_uuid(query_version_id)
        validate_uuid(record_id) if record_id
        validate_revision(revision) if revision
        raise ArgumentError, 'An exact revision needs its record identity.' if revision && !record_id
        body = {}
        { recordId: record_id, revision: revision, equals: equals, limit: limit, offset: offset }.each { |key, value| body[key] = value unless value.nil? }
        request(:post, "/queries/#{query_version_id}/execute", body)
      end
      def claim(subscription_id, limit: 50)
        validate_uuid(subscription_id)
        raise ArgumentError, 'Claim between one and 50 events.' unless limit.is_a?(Integer) && limit.between?(1, 50)
        request(:post, "/subscriptions/#{subscription_id}/claim", limit: limit)
      end
      def ack(subscription_id, event_id:, fence:)
        delivery_change(subscription_id, 'ack', event_id, fence)
      end
      def renew(subscription_id, event_id:, fence:)
        delivery_change(subscription_id, 'renew', event_id, fence)
      end
      def fail(subscription_id, event_id:, fence:, code:, retryable:)
        unless code.is_a?(String) && code.match?(/\A[A-Z][A-Z0-9_]{0,63}\z/) && [true, false].include?(retryable)
          raise ArgumentError, 'A classified delivery failure is required.'
        end
        delivery_change(subscription_id, 'fail', event_id, fence, code: code, retryable: retryable)
      end
      def delivery_status(subscription_id)
        validate_uuid(subscription_id)
        request(:get, "/subscriptions/#{subscription_id}/status")
      end
      private
      def validate_uuid(value)
        raise ArgumentError, 'An exact UUID reference is required.' unless value.is_a?(String) && value.match?(UUID)
      end
      def validate_revision(value)
        raise ArgumentError, 'A positive integer revision is required.' unless value.is_a?(Integer) && value.positive? && value <= 9_007_199_254_740_991
      end
      def delivery_change(subscription_id, action, event_id, fence, fields = {})
        [subscription_id, event_id, fence].each { |value| validate_uuid(value) }
        request(:post, "/subscriptions/#{subscription_id}/#{action}", { eventId: event_id, fence: fence }.merge(fields))
      end
      def request(method, path, body = nil)
        token = @token_provider.call
        raise ArgumentError, 'A current opaque credential is required.' unless token.is_a?(String) && token.match?(/\A[A-Za-z0-9_-]{32,256}\z/)
        uri = @origin.dup
        uri.path = '/api/integration/v1' + path
        message = method == :get ? Net::HTTP::Get.new(uri) : Net::HTTP::Post.new(uri)
        message['authorization'], message['x-data-action-workspace-id'] = "Bearer #{token}", @workspace_id
        message['x-data-action-integration-id'] = @profile_id if @profile_id
        if body
          serialized = JSON.generate(body)
          raise ArgumentError, 'Integration request exceeds the 64 KB limit.' if serialized.bytesize > 64_000
          message['content-type'], message.body = 'application/json', serialized
        end
        begin
          response = @transport.call(uri, message)
        rescue IOError, SystemCallError, Timeout::Error, OpenSSL::SSL::SSLError, EOFError
          raise TransportError.new(uncertain: method != :get), cause: nil
        end
        status = response.code.to_i
        raise ProtocolError, 'Integration redirects are not accepted.' if status.between?(300, 399)
        raise ProtocolError, 'Integration response exceeds the local safety limit.' if response.body.to_s.bytesize > 4_000_000
        begin
          value = JSON.parse(response.body.to_s)
        rescue JSON::ParserError
          raise ProtocolError, 'Integration response is not a JSON object.'
        end
        raise ProtocolError, 'Integration response is not a JSON object.' unless value.is_a?(Hash)
        unless status.between?(200, 299)
          error = value['error'].is_a?(Hash) ? value['error'] : {}
          code = error['code'].is_a?(String) && error['code'].match?(/\A[A-Z_]+\z/) ? error['code'] : 'UNAVAILABLE'
          raise RequestError.new(status: status, code: code, fields: error['fields'].is_a?(Array) ? error['fields'] : [])
        end
        value
      end
    end
  end
end

require 'securerandom'
require_relative 'delivery_errors'

module Cenit
  module DataAction
    # All transitions compare the current fence and the database clock atomically.
    module MongoWork
      def claim
        expired = scope.merge('state' => 'leased', 'attempts' => { '$gte' => 8 }, '$expr' => { '$lte' => ['$lease_until', '$$NOW'] })
        @collection.update_many(expired, [{ '$set' => { 'state' => 'dead_lettered', 'lease_until' => nil,
          'failure_code' => 'LEASE_EXPIRED', 'attempt_history' => finished_history('failed', 'LEASE_EXPIRED') } }])
        ready = scope.merge('attempts' => { '$lt' => 8 }, '$or' => [
          { 'state' => 'pending', '$expr' => { '$lte' => [{ '$ifNull' => ['$available_at', Time.at(0).utc] }, '$$NOW'] } },
          { 'state' => 'leased', '$expr' => { '$lte' => ['$lease_until', '$$NOW'] } }
        ])
        fence = SecureRandom.uuid
        next_attempt = { '$add' => ['$attempts', 1] }
        history = { '$cond' => [{ '$eq' => ['$state', 'leased'] }, finished_history('failed', 'LEASE_EXPIRED'), { '$ifNull' => ['$attempt_history', []] }] }
        @collection.find(ready).find_one_and_update([{ '$set' => {
          'state' => 'leased', 'fence' => fence, 'lease_until' => lease_expiry, 'attempts' => next_attempt,
          'attempt_history' => { '$concatArrays' => [history, [{ 'fence' => fence, 'attempt' => next_attempt, 'started_at' => '$$NOW', 'outcome' => 'leased' }]] }
        } }], sort: { 'accepted_at' => 1, '_id' => 1 }, return_document: :after)
      end
      def renew(id, fence:)
        transition(id, fence, 'lease_until' => lease_expiry)
      end
      def complete(id, fence:, receipt:)
        unless receipt.is_a?(Hash) && receipt.keys.sort == %w[bodyDigest effectKey receiptId] &&
            %w[bodyDigest effectKey].all? { |key| receipt[key].is_a?(String) && receipt[key].match?(/\A[0-9a-f]{64}\z/) } &&
            receipt['receiptId'].is_a?(String) && receipt['receiptId'].bytesize.between?(1, 200)
          raise ArgumentError, 'Only a verified bounded downstream receipt may be persisted.'
        end
        transition(id, fence, { 'state' => 'completed', 'lease_until' => nil, 'receipt' => { '$literal' => receipt },
          'completed_at' => '$$NOW', 'failure_code' => nil, 'attempt_history' => finished_history('completed', nil) },
          'effect_key' => receipt['effectKey'])
      end
      def fail(id, fence:, code:, retryable:)
        unless code.is_a?(String) && code.match?(/\A[A-Z][A-Z0-9_]{0,63}\z/) && [true, false].include?(retryable)
          raise ArgumentError, 'A classified work failure is required.'
        end
        state = retryable ? { '$cond' => [{ '$gte' => ['$attempts', 8] }, 'dead_lettered', 'pending'] } : 'dead_lettered'
        backoff = { '$min' => [300, { '$pow' => [2, '$attempts'] }] }
        transition(id, fence, 'state' => state, 'lease_until' => nil, 'failure_code' => code,
          'available_at' => { '$dateAdd' => { 'startDate' => '$$NOW', 'unit' => 'second', 'amount' => { '$toInt' => backoff } } },
          'attempt_history' => finished_history('failed', code))
      end
      def replay(id, actor_id:, reason:)
        unless actor_id.is_a?(String) && actor_id.bytesize.between?(1, 200) && reason.is_a?(String) && !reason.strip.empty? && reason.bytesize <= 500
          raise ArgumentError, 'A trusted operator and reviewed replay reason are required.'
        end
        review = { 'actor_id' => { '$literal' => actor_id }, 'reason' => { '$literal' => reason }, 'at' => '$$NOW' }
        result = @collection.find(scope.merge('_id' => id, 'state' => 'dead_lettered')).find_one_and_update([{ '$set' => {
          'state' => 'pending', 'attempts' => 0, 'fence' => nil, 'lease_until' => nil, 'available_at' => '$$NOW', 'failure_code' => nil,
          'replays' => { '$concatArrays' => [{ '$ifNull' => ['$replays', []] }, [review]] }
        } }], return_document: :after)
        raise ProtocolError, 'Only dead-lettered work can be replayed.' unless result
        result
      end
      def status(id)
        @collection.find(scope.merge('_id' => id)).first
      end
      private
      def scope
        { 'account_id' => @account, 'profile_id' => @profile }
      end
      def lease_expiry
        { '$dateAdd' => { 'startDate' => '$$NOW', 'unit' => 'second', 'amount' => 120 } }
      end
      def finished_history(outcome, code)
        { '$map' => { 'input' => { '$ifNull' => ['$attempt_history', []] }, 'as' => 'attempt', 'in' => {
          '$cond' => [{ '$eq' => ['$$attempt.fence', '$fence'] },
            { '$mergeObjects' => ['$$attempt', { 'finished_at' => '$$NOW', 'outcome' => outcome, 'failure_code' => code }] }, '$$attempt']
        } } }
      end
      def transition(id, fence, changes, conditions = {})
        filter = scope.merge('_id' => id, 'state' => 'leased', 'fence' => fence, '$expr' => { '$gt' => ['$lease_until', '$$NOW'] }).merge(conditions)
        result = @collection.find(filter).find_one_and_update([{ '$set' => changes }], return_document: :after)
        raise StaleWorkLease, 'The work lease is no longer current.' unless result
        result
      end
    end
  end
end

module Cenit
  module DataAction
    class DeliveryFailure < StandardError
      attr_reader :code, :retryable
      def initialize(code, retryable:)
        @code, @retryable = code, retryable
        super(code)
      end
    end
    class StaleWorkLease < StandardError; end
  end
end

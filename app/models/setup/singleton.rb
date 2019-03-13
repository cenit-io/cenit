module Setup
  module Singleton
    extend ActiveSupport::Concern

    def save(options = {})
      fail "Only one record is allowed for #{self.class}" if new_record? && self.class.count.positive?
      super
    end

    module ClassMethods

      def singleton_record
        find_or_create_by
      end

      def method_missing(symbol, *args, &block)
        if singleton_record.respond_to?(symbol)
          singleton_record.send(symbol, *args, &block)
        else
          super
        end
      end
    end
  end
end

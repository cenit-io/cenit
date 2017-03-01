module Setup
  module ChangedIf
    extend ActiveSupport::Concern

    included do
      class_attribute :changed_if_block
    end

    def changed?
      super || ((block = self.class.changed_if) && instance_eval(&block))
    end

    module ClassMethods
      def changed_if(&block)
        if block
          self.changed_if_block = block
        else
          changed_if_block
        end
      end
    end
  end
end

module Setup
  module ChangedIf
    extend ActiveSupport::Concern

    included do
      class_attribute :changed_if_blocks
      self.changed_if_blocks = []
    end

    def changed?
      super || self.class.changed_if_blocks.any? { |block| instance_eval(&block) }
    end

    module ClassMethods
      def changed_if(&block)
        if block
          self.changed_if_blocks << block
        end
      end
    end
  end
end

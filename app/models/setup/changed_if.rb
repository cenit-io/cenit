module Setup
  module ChangedIf
    extend ActiveSupport::Concern

    def changed?
      super || ((block = self.class.changed_if) && instance_eval(&block))
    end

    module ClassMethods

      def changed_if(&block)
        if block
          @changed_if = block
        else
          @changed_if
        end
      end
    end
  end
end
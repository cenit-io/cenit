module Setup
  module SharedConfigurable
    extend ActiveSupport::Concern

    include CrossOriginShared

    included do
      after_save { configure }
    end

    def configure
    end

    def save(options = {})
      if shared? && User.current != creator
        run_callbacks(:save) && configure
        errors.blank?
      else
        super
      end
    end

    module ClassMethods

      def configuring_fields
        @configuring_fields ||= Set.new
      end

      def shared_configurable(*args)
        configuring_fields.merge(args.collect(&:to_s).select(&:present?))
      end

      def tracked_field?(field, action = :update)
        configuring_fields.exclude?(field.to_s) && super
      end
    end
  end
end
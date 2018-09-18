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
      if do_configure_when_save?
        run_callbacks(:save) && configure
        errors.blank?
      else
        super
      end
    end

    def do_configure_when_save?
      auth_user = (Tenant.current && Tenant.current.owner) || User.current
      shared? && auth_user != creator
    end

    module ClassMethods

      def configuring_fields
        @configuring_fields ||= Set.new
      end

      def shared_configurable(*args)
        configuring_fields.merge(args.collect(&:to_s).select(&:present?))
      end

    end

  end
end

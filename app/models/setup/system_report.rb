module Setup
  class SystemReport
    include CenitUnscoped
    include Setup::SystemNotificationCommon
    include RailsAdmin::Models::Setup::SystemReportAdmin

    store_in collection: :setup_system_notifications

    deny :all

    build_in_data_type

    attachment_uploader GridFsUploader

    field :type, type: Symbol, default: :error
    field :message, type: String

    belongs_to :tenant, class_name: Cenit::MultiTenancy.tenant_model_name, inverse_of: nil

    before_save :catch_tenant

    def catch_tenant
      self.tenant ||= Cenit::MultiTenancy.tenant_model.current_tenant if new_record?
      true
    end

    def label
      "[#{type.to_s.capitalize}] #{message.length > 100 ? message.to(100) + '...' : message}"
    end

    class << self
      def new(attributes = {})
        attributes.delete(:skip_notification_level)
        super
      end
    end
  end
end

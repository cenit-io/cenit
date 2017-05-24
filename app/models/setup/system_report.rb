module Setup
  class SystemReport
    include CenitUnscoped
    include Setup::SystemNotificationCommon
    include RailsAdmin::Models::Setup::SystemReportAdmin

    store_in collection: :setup_notifications

    deny :all

    build_in_data_type

    attachment_uploader GridFsUploader

    field :type, type: Symbol, default: :error
    field :message, type: String

    def label
      "[#{type.to_s.capitalize}] #{message.length > 100 ? message.to(100) + '...' : message}"
    end
    
  end
end

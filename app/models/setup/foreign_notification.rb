module Setup
  class ForeignNotification
    include CenitScoped
    include RailsAdmin::Models::Setup::ForeignNotificationAdmin

    field :type, type: Symbol
    field :setting, type: Object

    has_and_belongs_to_many :observers, :class_name => Setup::Observer.name, :inverse_of => :foreign_notifications
    belongs_to :data_type, :class_name => Setup::DataType.name, :inverse_of => :foreign_notifications

    def type_enum
      {
        'E-Mail' => :email,
        'HTTP' => :http,
        'SMS' => :sms
      }
    end

  end
end

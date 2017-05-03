module Setup
  class ForeignNotification
    include CenitScoped
    include RailsAdmin::Models::Setup::ForeignNotificationAdmin

    field :name, type: String
    field :active, type: Boolean

    has_and_belongs_to_many :observers, :class_name => Setup::Observer.name, :inverse_of => :foreign_notifications
    belongs_to :data_type, :class_name => Setup::DataType.name, :inverse_of => :foreign_notifications

    deny :copy, :new, :edit, :export, :import, :translator_update

    # Virtual abstract method to send notification.
    def send_message(data)
      fail NotImplementedError
    end

    protected

    # Render data in handlebars template.
    def render(data, template, translator = nil)
      @object ||= data_type.records_model.find(data[:record][:id])

      translator ||= Transformation::HandlebarsTransform

      # Clone event data {record: {...}, account: {email: '...', name: '...', token: '...'}, event_time: '...'}
      options = data.clone
      options[:code] = template
      options[:source] = data[:record] # Legacy record data option.

      translator.run(options)
    end

  end
end
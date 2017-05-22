module Setup
  class ForeignNotification
    include CenitScoped
    include RailsAdmin::Models::Setup::ForeignNotificationAdmin

    field :name, type: String
    field :active, type: Boolean

    has_and_belongs_to_many :observers, :class_name => Setup::Observer.name, inverse_of: nil
    belongs_to :data_type, :class_name => Setup::DataType.name, inverse_of: nil

    deny :copy, :new, :edit, :export, :import, :translator_update

    # Virtual abstract method to send notification.
    def send_message(data)
      fail NotImplementedError
    end

    def label
      name
    end

    protected

    # Render data in handlebars template.
    def render(data, template)
      Transformation::HandlebarsTransform.run(render_options(data, template))
    end

    def render_options(data, template = nil)
      # Clone event data {record: {...}, account: {email: '...', name: '...', token: '...'}, event_time: '...'}
      options = data.deep_symbolize_keys
      options[:code] = template unless template.nil?
      # Legacy record data option.
      options[:source] = options[:record]
      options[:object_id] = options[:record][:id]
      options
    end

  end
end
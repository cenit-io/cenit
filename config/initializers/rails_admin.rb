[RailsAdmin::Config::Actions::MemoryUsage,
 RailsAdmin::Config::Actions::DiskUsage,
 RailsAdmin::Config::Actions::SendToFlow,
 RailsAdmin::Config::Actions::TestTransformation,
 RailsAdmin::Config::Actions::LoadModel,
 RailsAdmin::Config::Actions::ShutdownModel,
 RailsAdmin::Config::Actions::SwitchNavigation,
 RailsAdmin::Config::Actions::DataType,
 RailsAdmin::Config::Actions::Import,
 #RailsAdmin::Config::Actions::EdiExport,
 RailsAdmin::Config::Actions::ImportSchema,
 RailsAdmin::Config::Actions::DeleteAll,
 RailsAdmin::Config::Actions::Update,
 RailsAdmin::Config::Actions::Convert,
 RailsAdmin::Config::Actions::DeleteSchema,
 RailsAdmin::Config::Actions::ShareCollection,
 RailsAdmin::Config::Actions::PullCollection].each { |a| RailsAdmin::Config::Actions.register(a) }

RailsAdmin::Config::Actions.register(:export, RailsAdmin::Config::Actions::EdiExport)

RailsAdmin.config do |config|

  ## == PaperTrail ==
  # config.audit_with :paper_trail, 'User', 'PaperTrail::Version' # PaperTrail >= 3.0.0

  config.excluded_models << "Account"

  ### More at https://github.com/sferik/rails_admin/wiki/Base-configuration
  config.authenticate_with do
    warden.authenticate! scope: :user
  end
  config.current_user_method { current_user }
  config.audit_with :mongoid_audit
  config.authorize_with :cancan

  config.actions do
    dashboard # mandatory
    memory_usage
    disk_usage
    index # mandatory
    new { except [Setup::Event, Role] }
    import
    import_schema
    update
    convert
    export
    bulk_delete { except [Role] }
    show
    edit { except [Role] }
    share_collection
    pull_collection
    delete { except [Role] }
    delete_schema
    #show_in_app
    send_to_flow
    test_transformation
    load_model
    shutdown_model
    switch_navigation
    delete_all { except [Role] }
    data_type

    history_index do
      only [Setup::DataType, Setup::Webhook, Setup::Flow, Setup::Schema, Setup::Event, Setup::Connection, Setup::ConnectionRole, Setup::Library]
    end
    history_show do
      only [Setup::DataType, Setup::Webhook, Setup::Flow, Setup::Schema, Setup::Event, Setup::Connection, Setup::ConnectionRole, Setup::Notification, Setup::Library]
    end
  end

  config.model Role.name do
    weight -20
    navigation_label 'Accounts'
    show do
      field :name
      field :_id
    end
    fields :name
  end

  config.model Setup::SharedCollection do
    navigation_label 'Collections'
    weight -19
    edit do
      field :name
      field :description
    end
    show do
      field :name
      field :description

      field :created_at
      field :creator
      field :updated_at
    end
    fields :name, :creator, :description
  end

  config.model Setup::Collection do
    navigation_label 'Collections'
    weight -18
    show do
      field :name
      field :libraries
      field :translators
      field :events
      field :connection_roles
      field :webhooks
      field :flows

      field :_id
      field :created_at
      field :creator
      field :updated_at
      field :updater
    end
    fields :name, :libraries, :translators, :events, :connection_roles, :webhooks, :flows
  end

  config.model Setup::Library.name do
    navigation_label 'Data Definitions'
    weight -16

    configure :name do
      read_only { !bindings[:object].new_record? }
      help ''
    end

    edit do
      field :name
    end

    show do
      field :name
      field :schemas

      field :_id
      field :created_at
      field :creator
      field :updated_at
      field :updater
    end

    fields :name, :schemas
  end

  config.model Setup::Schema.name do
    navigation_label 'Data Definitions'
    weight -18

    object_label_method { :uri }

    configure :library do
      read_only { !bindings[:object].new_record? }
      inline_edit false
    end

    configure :uri do
      read_only { !bindings[:object].new_record? }
      html_attributes do
        {cols: '74', rows: '1'}
      end
    end

    configure :schema, :text do
      html_attributes do
        {cols: '74', rows: '15'}
      end
    end

    show do
      field :library
      field :uri
      field :schema
      field :data_types

      field :_id
      field :created_at
      field :creator
      field :updated_at
      field :updater
    end
    fields :library, :uri, :schema
  end

  config.model Setup::DataType.name do
    navigation_label 'Data Definitions'
    weight -17

    group :model_definition do
      label 'Model definition'
      active true
    end

    group :sample_data do
      label 'Sample data'
      active do
        !bindings[:object].errors.get(:sample_data).blank?
      end
      visible do
        bindings[:object].is_object
      end
    end

    configure :uri do
      group :model_definition
      read_only true
      help ''
    end

    configure :name do
      group :model_definition
      read_only true
      help ''
    end

    configure :schema, :text do
      group :model_definition
      read_only true
      help ''
      html_attributes do
        {cols: '50', rows: '15'}
      end
    end

    configure :sample_data, :text do
      group :sample_data
      html_attributes do
        {cols: '70', rows: '15'}
      end
    end

    configure :collection_size, :decimal do
      pretty_value do
        unless max = bindings[:controller].instance_variable_get(:@max_collection_size)
          bindings[:controller].instance_variable_set(:@max_collection_size, max = bindings[:controller].instance_variable_get(:@objects).collect { |data_type| data_type.records_model.collection_size }.max)
        end
        (bindings[:view].render partial: 'used_memory_bar', locals: {max: max, value: bindings[:object].records_model.collection_size}).html_safe
      end
      read_only true
    end

    list do
      field :uri
      field :name
      field :used_memory do
        pretty_value do
          unless max = bindings[:controller].instance_variable_get(:@max_used_memory)
            bindings[:controller].instance_variable_set(:@max_used_memory, max = Setup::DataType.fields[:used_memory.to_s].type.new(Setup::DataType.max(:used_memory)))
          end
          (bindings[:view].render partial: 'used_memory_bar', locals: {max: max, value: Setup::DataType.fields[:used_memory.to_s].type.new(value)}).html_safe
        end
      end
      field :collection_size
    end

    show do
      field :uri
      field :name
      field :activated
      field :schema
      field :sample_data

      field :_id
      field :created_at
      field :creator
      field :updated_at
      field :updater
    end
    fields :uri, :name, :used_memory
  end

  config.model Setup::Connection.name do
    weight -15
    group :credentials do
      label "Credentials"
    end
    configure :name, :string do
      help 'Requiered.'
      html_attributes do
        {maxlength: 30, size: 30}
      end
    end
    configure :url, :string do
      help 'Requiered.'
      html_attributes do
        {maxlength: 50, size: 50}
      end
    end
    configure :key, :string do
      visible { bindings[:view]._current_user.has_role? :admin }
      html_attributes do
        {maxlength: 30, size: 30}
      end
      group :credentials
    end
    configure :token, :text do
      visible { bindings[:view]._current_user.has_role? :admin }
      html_attributes do
        {cols: '50', rows: '1'}
      end
      group :credentials
    end
    configure :parameters do
      visible { bindings[:view]._current_user.has_role? :admin }
    end
    configure :headers do
      visible { bindings[:view]._current_user.has_role? :admin }
    end

    group :parameters do
      label "Add Parameters"
    end
    configure :parameters do
      group :parameters
    end
    configure :headers do
      group :parameters
    end

    show do
      field :name
      field :url

      field :key
      field :token

      field :parameters
      field :headers

      field :_id
      field :created_at
      field :creator
      field :updated_at
      field :updater
    end

    fields :name, :url, :webhooks, :parameters, :headers, :key, :token
  end

  config.model Setup::Parameter.name do
    object_label_method { :to_s }
    edit do
      field :key
      field :value
    end
  end

  config.model Setup::ConnectionRole.name do
    weight -14
    configure :name, :string do
      help 'Requiered.'
      html_attributes do
        {maxlength: 50, size: 50}
      end
    end
    configure :connections do
      nested_form false
    end
    modal do
      field :name
      field :connections
      #field :webhooks
    end
    show do
      field :name
      field :connections

      field :_id
      field :created_at
      field :creator
      field :updated_at
      field :updater
    end
    fields :name, :connections
  end

  config.model Setup::Webhook.name do
    weight -13

    configure :path, :string do
      help "Requiered. Path of the webhook relative to connection URL."
      html_attributes do
        {maxlength: 50, size: 50}
      end
    end
    group :parameters do
      label "Add Parameters"
    end
    configure :parameters do
      group :parameters
    end
    configure :headers do
      group :parameters
    end

    show do
      field :name
      field :purpose
      field :path
      field :method

      field :parameters
      field :headers

      field :_id
      field :created_at
      field :creator
      field :updated_at
      field :updater
    end
    fields :name, :purpose, :path, :method, :parameters, :headers
  end

  config.model Setup::Notification.name do
    weight -10
    navigation_label 'Notifications'
    show do
      field :flow
      field :http_status_code
      field :count
      field :http_status_message
      field :json_data

      field :_id
      field :created_at
      field :creator
      field :updated_at
      field :updater
    end
    fields :flow, :http_status_code, :count, :http_status_message, :json_data
  end

  config.model Setup::Flow.name do
    register_instance_option(:form_synchronized) do
      [:custom_data_type, :data_type_scope, :lot_size, :connection_role, :webhook, :response_translator, :response_data_type]
    end
    edit do
      field :name
      field :event do
        inline_edit false
        inline_add false
      end
      field :translator
      field :custom_data_type do
        inline_edit false
        inline_add false
        visible do
          if (f = bindings[:object]).event && f.translator && f.translator.data_type.nil?
            f.instance_variable_set(:@selecting_data_type, f.custom_data_type = f.event && f.event.try(:data_type)) unless f.data_type
            true
          else
            false
          end
        end
        label do
          if (translator = bindings[:object].translator)
            if [:Export, :Conversion].include?(translator.type)
              'Source data type'
            else
              'Target data type'
            end
          else
            'Data type'
          end
        end
        help 'Required'
      end
      field :data_type_scope do
        visible { (f = bindings[:object]).event && f.translator && f.translator.type != :Import && f.data_type && !f.instance_variable_get(:@selecting_data_type) }
        label do
          if (translator = bindings[:object].translator)
            if [:Export, :Conversion].include?(translator.type)
              'Source scope'
            else
              'Target scope'
            end
          else
            'Data type scope'
          end
        end
        help 'Required'
      end
      field :lot_size do
        visible { (f = bindings[:object]).event && f.translator && f.translator.type == :Export && f.data_type_scope && f.scope_symbol != :event_source }
      end
      field :connection_role do
        visible { (translator = bindings[:object].translator) && (translator.type == :Import || (translator.type == :Export && bindings[:object].data_type_scope.present?)) }
        help 'Required'
      end
      field :webhook do
        visible { (translator = bindings[:object].translator) && (translator.type == :Import || (translator.type == :Export && bindings[:object].data_type_scope.present?)) }
        help 'Required'
      end
      field :response_translator do
        visible { (translator = bindings[:object].translator) && translator.type == :Export && bindings[:object].ready_to_save? }
        associated_collection_scope do
          Proc.new { |scope|
            scope.where(type: :Import)
          }
        end
      end
      field :response_data_type do
        inline_edit false
        inline_add false
        visible { (response_translator = bindings[:object].response_translator) && response_translator.type == :Import && response_translator.data_type.nil? }
        help ''
      end
      field :discard_events do
        visible { bindings[:object].ready_to_save? }
        help "Events won't be fired for created or updated records if checked"
      end
      field :active do
        visible { bindings[:object].ready_to_save? }
      end
    end

    show do
      field :name
      field :event
      field :translator

      field :_id
      field :created_at
      field :creator
      field :updated_at
      field :updater
    end

    fields :name, :event, :translator
  end

  config.model Setup::Event do
    edit do
      field :name
    end

    show do
      field :name
      field :last_trigger_timestamps

      field :_id
      field :created_at
      field :creator
      field :updated_at
      field :updater
    end

    fields :name, :last_trigger_timestamps
  end

  config.model Setup::Observer do
    edit do
      field :name
      field :data_type do
        help false
        inline_add false
        inline_edit false
        associated_collection_scope do
          Proc.new { |scope|
            scope = scope.where(activated: true)
          }
        end
      end
      field :triggers do
        partial 'form_triggers'
        help false
      end
    end

    show do
      field :name
      field :data_type
      field :triggers
      field :last_trigger_timestamps

      field :_id
      field :created_at
      field :creator
      field :updated_at
      field :updater
    end

    fields :name, :data_type, :triggers, :last_trigger_timestamps
  end

  config.model Setup::Scheduler do
    edit do
      field :name
      field :scheduling_method
      field :expression do
        visible { bindings[:object].scheduling_method.present? }
        label do
          case bindings[:object].scheduling_method
          when :Once
            'Date and time'
          when :Periodic
            'Duration'
          when :CRON
            'CRON Expression'
          else
            'Expression'
          end
        end
        help do
          case bindings[:object].scheduling_method
          when :Once
            'Select a date and a time'
          when :Periodic
            'Type a time duration'
          when :CRON
            'Type a CRON Expression'
          else
            'Expression'
          end
        end
        partial { bindings[:object].scheduling_method == :Once ? 'form_datetime_wrapper' : 'form_text' }
        html_attributes do
          {rows: '1'}
        end
      end
    end

    show do
      field :name
      field :expression
      field :last_trigger_timestamps

      field :_id
      field :created_at
      field :creator
      field :updated_at
      field :updater
    end

    fields :name, :scheduling_method, :expression, :last_trigger_timestamps
  end

  config.model Setup::Translator do
    register_instance_option(:form_synchronized) do
      [:source_data_type, :target_data_type, :transformation, :target_importer, :source_exporter, :discard_chained_records]
    end
    edit do
      field :name

      field :type

      field :source_data_type do
        inline_edit false
        inline_add false
        visible { [:Export, :Conversion].include?(bindings[:object].type) }
        help { bindings[:object].type == :Conversion ? 'Required' : 'Optional' }
      end

      field :bulk_source do
        visible { bindings[:object].type == :Export }
      end

      field :target_data_type do
        inline_edit false
        inline_add false
        visible { [:Import, :Update, :Conversion].include?(bindings[:object].type) }
        help { bindings[:object].type == :Conversion ? 'Required' : 'Optional' }
      end

      field :discard_events do
        visible { [:Import, :Update, :Conversion].include?(bindings[:object].type) }
        help "Events won't be fired for created or updated records if checked"
      end

      field :style do
        visible { bindings[:object].type.present? }
      end

      field :mime_type do
        label 'MIME type'
        visible { bindings[:object].type == :Export }
      end

      field :file_extension do
        visible { bindings[:object].type == :Export && !bindings[:object].file_extension_enum.empty? }
        help { "Extensions for #{bindings[:object].mime_type}" }
      end

      field :transformation do
        visible { bindings[:object].style.present? && bindings[:object].style != 'chain' }
        html_attributes do
          {cols: '74', rows: '15'}
        end
      end

      field :source_exporter do
        inline_add { bindings[:object].source_exporter.nil? }
        visible { bindings[:object].style == 'chain' && bindings[:object].source_data_type && bindings[:object].target_data_type }
        help 'Required'
        associated_collection_scope do
          data_type = bindings[:object].source_data_type
          Proc.new { |scope|
            scope.all(type: :Conversion, source_data_type: data_type)
          }
        end
      end

      field :target_importer do
        inline_add { bindings[:object].target_importer.nil? }
        visible { bindings[:object].style == 'chain' && bindings[:object].source_data_type && bindings[:object].target_data_type && bindings[:object].source_exporter }
        help 'Required'
        associated_collection_scope do
          translator = bindings[:object]
          source_data_type = if translator.source_exporter
                               translator.source_exporter.target_data_type
                             else
                               translator.source_data_type
                             end
          target_data_type = bindings[:object].target_data_type
          Proc.new { |scope|
            scope = scope.all(type: :Conversion,
                              source_data_type: source_data_type,
                              target_data_type: target_data_type)
          }
        end
      end

      field :discard_chained_records do
        visible { bindings[:object].style == 'chain' && bindings[:object].source_data_type && bindings[:object].target_data_type && bindings[:object].source_exporter }
        help "Chained records won't be saved if checked"
      end
    end

    show do
      field :name
      field :type
      field :source_data_type
      field :bulk_source
      field :target_data_type
      field :discard_events
      field :style
      field :mime_type
      field :file_extension
      field :transformation
      field :source_exporter
      field :target_importer
      field :discard_chained_records

      field :_id
      field :created_at
      field :creator
      field :updated_at
      field :updater
    end

    fields :name, :type, :style, :transformation
  end

end

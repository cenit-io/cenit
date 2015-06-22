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
 RailsAdmin::Config::Actions::TranslatorUpdate,
 RailsAdmin::Config::Actions::Convert,
 RailsAdmin::Config::Actions::DeleteSchema,
 RailsAdmin::Config::Actions::DeleteLibrary,
 RailsAdmin::Config::Actions::SimpleShare,
 RailsAdmin::Config::Actions::BulkShare,
 RailsAdmin::Config::Actions::PullCollection,
 RailsAdmin::Config::Actions::RetryNotification,
 RailsAdmin::Config::Actions::NewFileModel,
 RailsAdmin::Config::Actions::UploadFile,
 RailsAdmin::Config::Actions::DownloadFile,
 RailsAdmin::Config::Actions::DeleteDataType,
 RailsAdmin::Config::Actions::ProcessFlow].each { |a| RailsAdmin::Config::Actions.register(a) }

RailsAdmin::Config::Actions.register(:export, RailsAdmin::Config::Actions::EdiExport)
RailsAdmin::Config::Fields::Types.register(RailsAdmin::Config::Fields::Types::JsonSchema)
{
    config: {
        mode: 'css',
        theme: 'neo',
    },
    assets: {
        mode: '/assets/codemirror/modes/css.js',
        theme: '/assets/codemirror/themes/neo.css',
    }
}.each { |option, configuration| RailsAdmin::Config::Fields::Types::CodeMirror.register_instance_option(option) { configuration } }

RailsAdmin.config do |config|

  ## == PaperTrail ==
  # config.audit_with :paper_trail, 'User', 'PaperTrail::Version' # PaperTrail >= 3.0.0

  config.excluded_models += [Account, Setup::Validator]

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
    new_file_model
    import
    import_schema
    translator_update
    convert
    #import do
    #  only 'Setup::DataType'
    #end
    export
    bulk_delete { except [Role] }
    show
    edit { except [Role] }
    simple_share
    bulk_share
    pull_collection
    upload_file
    download_file
    load_model
    shutdown_model
    process_flow
    delete_data_type
    delete { except [Role] }
    delete_schema
    delete_library
    #show_in_app
    send_to_flow
    test_transformation
    switch_navigation
    delete_all { except [Role] }
    data_type
    retry_notification

    history_index do
      only [Setup::Model, Setup::Webhook, Setup::Flow, Setup::Schema, Setup::Event, Setup::Connection, Setup::ConnectionRole, Setup::Library]
    end
    history_show do
      only [Setup::Model, Setup::Webhook, Setup::Flow, Setup::Schema, Setup::Event, Setup::Connection, Setup::ConnectionRole, Setup::Notification, Setup::Library]
    end
  end

  config.model Role do
    weight -20
    navigation_label 'Account'
    show do
      field :name
      field :_id
    end
    fields :name
  end

  config.model Setup::Library do
    navigation_label 'Data Definitions'
    weight -16

    configure :name do
      read_only { !bindings[:object].new_record? }
      help ''
    end

    edit do
      field :name
      field :slug
    end

    show do
      field :name
      field :slug
      field :schemas
      field :file_data_types

      field :_id
      field :created_at
      #field :creator
      field :updated_at
      #field :updater
    end

    fields :name, :slug, :schemas, :file_data_types
  end

  config.model Setup::Schema do
    object_label_method { :on_library_title }
    navigation_label 'Data Definitions'
    register_instance_option(:after_form_partials) do
      %w(shutdown_and_reload)
    end
    weight -18

    edit do
      field :library do
        read_only { !bindings[:object].new_record? }
        inline_edit false
      end

      field :uri do
        read_only { !bindings[:object].new_record? }
        html_attributes do
          {cols: '74', rows: '1'}
        end
      end

      field :schema, :code_mirror do
        html_attributes do
          reload = Setup::Model.shutdown(bindings[:object].data_types.activated, report_only: true)[:destroyed].collect(&:data_type).uniq #.select(&:activated)
          bindings[:object].instance_variable_set(:@_to_reload, reload)
          {cols: '74', rows: '15'}
        end
      end
    end

    show do
      field :library
      field :uri
      field :schema do
        pretty_value do
          pretty_value =
              if json = JSON.parse(value) rescue nil
                "<code class='json'>#{JSON.pretty_generate(json)}</code>"
              elsif xml = Nokogiri::XML(value) rescue nil
                "<code class='xml'>#{xml.to_xml}</code>"
              else
                value
              end
          #"<textarea id='code' name='code'>#{pretty_value}</textarea>".html_safe
          "<pre>#{pretty_value}</pre>".html_safe
        end
      end
      field :data_types

      field :_id
      field :created_at
      #field :creator
      field :updated_at
      #field :updater

    end
    fields :library, :uri, :data_types
  end

  config.model Setup::Model do
    label 'Data type'
    label_plural 'Data types'
    object_label_method { :on_library_title }
    navigation_label 'Data Definitions'
    weight -17

    configure :title do
      pretty_value do
        bindings[:object].on_library_title
      end
    end

    configure :validator, :text do
      pretty_value do
        if value
          am = (amc = RailsAdmin::Config.model(value.class)).abstract_model
          (v = bindings[:view]).link_to(value.send(amc.object_label_method), v.url_for(action: v.action(:show, am, value).action_name, model_name: am.to_param, id: value.id), class: 'pjax')
        end
      end
    end

    configure :storage_size, :decimal do
      pretty_value do
        unless max = bindings[:controller].instance_variable_get(:@max_storage_size)
          bindings[:controller].instance_variable_set(:@max_storage_size, max = bindings[:controller].instance_variable_get(:@objects).collect { |data_type| data_type.storage_size }.max)
        end
        (bindings[:view].render partial: 'used_memory_bar', locals: {max: max, value: bindings[:object].records_model.storage_size}).html_safe
      end
      read_only true
    end

    list do
      field :title
      field :validator
      field :name
      field :used_memory do
        pretty_value do
          unless max = bindings[:controller].instance_variable_get(:@max_used_memory)
            bindings[:controller].instance_variable_set(:@max_used_memory, max = Setup::Model.fields[:used_memory.to_s].type.new(Setup::Model.max(:used_memory)))
          end
          (bindings[:view].render partial: 'used_memory_bar', locals: {max: max, value: Setup::Model.fields[:used_memory.to_s].type.new(value)}).html_safe
        end
      end
      field :storage_size
    end

    show do
      field :title
      field :name
      field :activated
      field :validator
      field :model_schema do
        pretty_value do
          pretty_value =
              if json = JSON.parse(value) rescue nil
                "<code class='json'>#{JSON.pretty_generate(json)}</code>"
              elsif xml = Nokogiri::XML(value) rescue nil
                "<code class='xml'>#{xml.to_xml}</code>"
              else
                value
              end
          #"<textarea id='code' name='code'>#{pretty_value}</textarea>".html_safe
          "<pre>#{pretty_value}</pre>".html_safe
        end
      end

      field :_id
      field :created_at
      #field :creator
      field :updated_at
      #field :updater
    end
    fields :title, :validator, :name, :used_memory
  end

  config.model Setup::EdiValidator do
    label 'EDI Validators'
    navigation_label 'Data Definitions'

    fields :name, :schema, :content_type
  end

  config.model Setup::FileDataType do
    visible false
    register_instance_option(:discard_submit_buttons) do
      !(a = bindings[:action]) || a.key != :edit
    end
    edit do
      field :library do
        associated_collection_scope do
          library = (obj = bindings[:object]).library
          Proc.new { |scope|
            if library
              scope.where(id: library.id)
            else
              scope
            end
          }
        end
      end
      field :name
      field :validator do
        inline_add false
        inline_edit false
      end
    end
    fields :name, :library, :validator
  end

  config.model Setup::DataType do
    visible false
    object_label_method { :on_library_title }
    navigation_label 'Data Definitions'
    weight -17

    group :model_definition do
      label 'Model definition'
      active true
    end

    configure :schema do
      group :model_definition
      read_only true
      help ''
    end

    configure :title do
      group :model_definition
      help ''
      pretty_value do
        bindings[:object].on_library_title
      end
    end

    configure :name do
      group :model_definition
      read_only true
      help ''
    end

    configure :model_schema, :text do
      group :model_definition
      read_only true
      help ''
      html_attributes do
        {cols: '50', rows: '15'}
      end
      pretty_value do
        "<pre><code class='json'>#{JSON.pretty_generate(JSON.parse(value))}</code></pre>".html_safe
      end
    end

    configure :storage_size, :decimal do
      pretty_value do
        unless max = bindings[:controller].instance_variable_get(:@max_storage_size)
          bindings[:controller].instance_variable_set(:@max_storage_size, max = bindings[:controller].instance_variable_get(:@objects).collect { |data_type| data_type.records_model.storage_size }.max)
        end
        (bindings[:view].render partial: 'used_memory_bar', locals: {max: max, value: bindings[:object].records_model.storage_size}).html_safe
      end
      read_only true
    end

    list do
      field :title
      field :schema
      field :name
      field :used_memory do
        pretty_value do
          unless max = bindings[:controller].instance_variable_get(:@max_used_memory)
            bindings[:controller].instance_variable_set(:@max_used_memory, max = Setup::DataType.fields[:used_memory.to_s].type.new(Setup::DataType.max(:used_memory)))
          end
          (bindings[:view].render partial: 'used_memory_bar', locals: {max: max, value: Setup::DataType.fields[:used_memory.to_s].type.new(value)}).html_safe
        end
      end
      field :storage_size
    end

    show do
      field :title
      field :schema
      field :name
      field :activated
      field :model_schema

      field :_id
      field :created_at
      #field :creator
      field :updated_at
      #field :updater
    end
    fields :title, :schema, :name, :used_memory
  end

  config.model Setup::Connection do
    weight -15
    configure :name, :string do
      help 'Requiered.'
      html_attributes do
        {maxlength: 30, size: 30}
      end
    end
    configure :url do
      html_attributes do
        {cols: '50', rows: '1'}
      end
    end
    group :credentials do
      label "Credentials"
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

    group :parameters do
      label "Parameters & Headers"
    end
    configure :parameters do
      group :parameters
      visible { bindings[:view]._current_user.has_role? :admin }
    end
    configure :headers do
      group :parameters
      visible { bindings[:view]._current_user.has_role? :admin }
    end
    configure :template_parameters do
      group :parameters
      visible { bindings[:view]._current_user.has_role? :admin }
    end

    show do
      field :name
      field :url

      field :key
      field :token

      field :parameters
      field :headers
      field :template_parameters

      field :_id
      field :created_at
      #field :creator
      field :updated_at
      #field :updater
    end

    fields :name, :url, :parameters, :headers, :template_parameters, :key, :token
  end

  config.model Setup::Parameter do
    object_label_method { :to_s }
    edit do
      field :key
      field :value
    end
  end

  config.model Setup::ConnectionRole do
    weight -14
    configure :name, :string do
      help 'Requiered.'
      html_attributes do
        {maxlength: 50, size: 50}
      end
    end
    configure :webhooks do
      nested_form false
    end
    configure :connections do
      nested_form false
    end
    modal do
      field :name
      field :webhooks
      field :connections
    end
    show do
      field :name
      field :webhooks
      field :connections

      field :_id
      field :created_at
      #field :creator
      field :updated_at
      #field :updater
    end
    fields :name, :webhooks, :connections
  end

  config.model Setup::Webhook do
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
    configure :template_parameters do
      group :parameters
    end

    show do
      field :name
      field :purpose
      field :path
      field :method

      field :parameters
      field :headers
      field :template_parameters

      field :_id
      field :created_at
      #field :creator
      field :updated_at
      #field :updater
    end
    fields :name, :purpose, :path, :method, :parameters, :headers, :template_parameters
  end

  config.model Setup::Notification do
    weight -10
    navigation_label 'Notifications'
    configure :exception_message do
      pretty_value do
        "<label style='color:red'>#{value}</label>".html_safe
      end
    end
    show do
      field :flow
      field :retries
      field :response
      field :exception_message

      field :_id
      field :created_at
      #field :creator
      field :updated_at
      #field :updater
    end
    fields :flow, :created_at, :retries, :response, :exception_message
  end

  config.model Setup::Flow do
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
          if (f = bindings[:object]).custom_data_type.present?
            f.nil_data_type = false
          end
          if f.translator.present? && f.translator.data_type.nil? && !f.nil_data_type
            f.instance_variable_set(:@selecting_data_type, f.custom_data_type = f.event && f.event.try(:data_type)) unless f.data_type
            f.nil_data_type = f.translator.type == :Export && (params = (controller = bindings[:controller]).params) && (params = params[controller.abstract_model.param_key]) && params[:custom_data_type_id].blank? && params.keys.include?(:custom_data_type_id.to_s)
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
        help do
          if bindings[:object].nil_data_type
            ''
          elsif (translator = bindings[:object].translator) && [:Export, :Conversion].include?(translator.type)
            'Optional'
          else
            'Required'
          end
        end
      end
      field :nil_data_type do
        visible { bindings[:object].nil_data_type }
        label do
          if (translator = bindings[:object].translator)
            if [:Export, :Conversion].include?(translator.type)
              'No source data type'
            else
              'No target data type'
            end
          else
            'No data type'
          end
        end
      end
      field :data_type_scope do
        visible do
          bindings[:controller].instance_variable_set(:@_data_type, bindings[:object].data_type)
          bindings[:controller].instance_variable_set(:@_update_field, 'translator_id')
          (f = bindings[:object]).translator.present? && f.translator.type != :Import && f.data_type && !f.instance_variable_get(:@selecting_data_type)
        end
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
      field :scope_filter do
        visible { bindings[:object].scope_symbol == :filtered }
        partial 'form_triggers'
        help false
      end
      field :lot_size do
        visible { (f = bindings[:object]).translator.present? && f.translator.type == :Export && !f.nil_data_type && f.data_type_scope && f.scope_symbol != :event_source }
      end
      field :webhook do
        visible { (translator = (f = bindings[:object]).translator) && (translator.type == :Import || (translator.type == :Export && (bindings[:object].data_type_scope.present? || f.nil_data_type))) }
        help 'Required'
      end
      field :connection_role do
        visible { (translator = (f = bindings[:object]).translator) && (translator.type == :Import || (translator.type == :Export && (bindings[:object].data_type_scope.present? || f.nil_data_type))) }
        help 'Optional'
      end
      field :response_translator do
        visible { (translator = (f = bindings[:object]).translator) && (translator.type == :Export && (bindings[:object].data_type_scope.present? || f.nil_data_type)) && f.ready_to_save? }
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
        visible { bindings[:object].response_translator.present? && bindings[:object].ready_to_save? }
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
      #field :creator
      field :updated_at
      #field :updater
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
      #field :creator
      field :updated_at
      #field :updater
    end

    fields :name, :last_trigger_timestamps
  end

  config.model Setup::Observer do
    edit do
      field :name
      field :data_type do
        associated_collection_scope do
          bindings[:controller].instance_variable_set(:@_data_type, data_type = bindings[:object].data_type)
          bindings[:controller].instance_variable_set(:@_update_field, 'data_type_id')
          Proc.new { |scope|
            if data_type
              scope.where(id: data_type.id)
            else
              scope
            end
          }
        end
      end
      field :triggers do
        visible { bindings[:object].data_type.present? }
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
      #field :creator
      field :updated_at
      #field :updater
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
      #field :creator
      field :updated_at
      #field :updater
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

      field :bulk_source do
        visible { bindings[:object].type == :Export && bindings[:object].style.present? && bindings[:object].source_bulkable? }
      end

      field :mime_type do
        label 'MIME type'
        visible { bindings[:object].type == :Export && bindings[:object].style.present? }
      end

      field :file_extension do
        visible { bindings[:object].type == :Export && !bindings[:object].file_extension_enum.empty? }
        help { "Extensions for #{bindings[:object].mime_type}" }
      end

      field :transformation, :code_mirror do
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
          source_data_type =
              if translator.source_exporter
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
      #field :creator
      field :updated_at
      #field :updater
    end

    fields :name, :type, :style, :transformation
  end

  config.model Setup::SharedName do
    visible { false }
    navigation_label 'Collections'
    fields :name, :owners
  end

  config.model Setup::SharedCollection do
    register_instance_option(:discard_submit_buttons) do
      !(a = bindings[:action]) || a.key != :edit
    end
    navigation_label 'Collections'
    object_label_method { :versioned_name }
    weight -19
    edit do
      field :image do
        visible { !bindings[:object].new_record? }
      end
      field :name
      field :shared_version
      field :description, :wysihtml5
      field :source_collection do
        visible { !((source_collection = bindings[:object].source_collection) && source_collection.new_record?) }
        inline_edit false
        inline_add false
        associated_collection_scope do
          source_collection = (obj = bindings[:object]).source_collection
          Proc.new { |scope|
            if obj.new_record?
              scope.where(id: source_collection ? source_collection.id : nil)
            else
              scope
            end
          }
        end
      end
      field :connections do
        inline_add false
        read_only do
          !bindings[:object].instance_variable_get(:@_selecting_connections)
        end
        help do
          nil
        end
        pretty_value do
          if bindings[:object].connections.present?
            v = bindings[:view]
            ids = ''
            [value].flatten.select(&:present?).collect do |associated|
              ids += "<option value=#{associated.id} selected=true/>"
              amc = polymorphic? ? RailsAdmin.config(associated) : associated_model_config
              am = amc.abstract_model
              wording = associated.send(amc.object_label_method)
              can_see = !am.embedded? && (show_action = v.action(:show, am, associated))
              can_see ? v.link_to(wording, v.url_for(action: show_action.action_name, model_name: am.to_param, id: associated.id), class: 'pjax') : wording
            end.to_sentence.html_safe +
                v.select_tag("#{bindings[:controller].instance_variable_get(:@model_config).abstract_model.param_key}[connection_ids][]", ids.html_safe, multiple: true, style: 'display:none').html_safe
          else
            'No connection selected'.html_safe
          end
        end
        visible do
          !(obj = bindings[:object]).instance_variable_get(:@_selecting_collection) && obj.source_collection && obj.source_collection.connections.present?
        end
        associated_collection_scope do
          source_collection = bindings[:object].source_collection
          connections = (source_collection && source_collection.connections) || []
          Proc.new { |scope|
            scope.any_in(id: connections.collect { |connection| connection.id })
          }
        end
      end
      field :dependencies do
        inline_add false
        read_only do
          !bindings[:object].instance_variable_get(:@_selecting_connections)
        end
        help do
          nil
        end
        pretty_value do
          if bindings[:object].dependencies.present?
            v = bindings[:view]
            ids = ''
            [value].flatten.select(&:present?).collect do |associated|
              ids += "<option value=#{associated.id} selected=true/>"
              amc = polymorphic? ? RailsAdmin.config(associated) : associated_model_config
              am = amc.abstract_model
              wording = associated.send(amc.object_label_method)
              can_see = !am.embedded? && (show_action = v.action(:show, am, associated))
              can_see ? v.link_to(wording, v.url_for(action: show_action.action_name, model_name: am.to_param, id: associated.id), class: 'pjax') : wording
            end.to_sentence.html_safe +
                v.select_tag("#{bindings[:controller].instance_variable_get(:@model_config).abstract_model.param_key}[dependency_ids][]", ids.html_safe, multiple: true, style: 'display:none').html_safe
          else
            'No dependencies selected'.html_safe
          end
        end
        visible do
          !(obj = bindings[:object]).instance_variable_get(:@_selecting_collection)
        end
      end
      field :pull_parameters do
        visible do
          if !(obj = bindings[:object]).instance_variable_get(:@_selecting_collection) &&
              !obj.instance_variable_get(:@_selecting_connections) &&
              (pull_parameters_enum = obj.enum_for_pull_parameters).present?
            bindings[:controller].instance_variable_set(:@shared_parameter_enum, pull_parameters_enum)
            true
          else
            false
          end
        end
      end
    end
    show do
      field :image
      field :name do
        pretty_value do
          bindings[:object].versioned_name
        end
      end
      field :category
      field :description do
        pretty_value do
          value.html_safe
        end
      end
      field :owners, :text do
        pretty_value do
          value.collect { |user| user.email }.to_sentence.html_safe
        end
      end
      field :dependencies

      field :_id
      field :created_at
      field :updated_at
    end
    list do
      field :image
      field :name do
        pretty_value do
          bindings[:object].versioned_name
        end
      end
      field :category
      field :owners, :text do
        pretty_value do
          value.collect { |user| user.email }.to_sentence.html_safe
        end
      end
      field :description do
        pretty_value do
          value.html_safe
        end
      end
    end
  end

  config.model Setup::CollectionPullParameter do
    object_label_method { :label }
    field :label
    field :parameter, :enum do
      enum do
        bindings[:controller].instance_variable_get(:@shared_parameter_enum) || [bindings[:object].parameter]
      end
    end
    edit do
      field :label
      field :parameter
    end
    show do
      field :label
      field :parameter

      field :created_at
      #field :creator
      field :updated_at
    end
    fields :label, :parameter
  end

  config.model Setup::Collection do
    navigation_label 'Collections'
    weight -19
    show do
      field :image
      field :name
      field :flows
      field :connection_roles
      field :translators
      field :events
      field :libraries
      field :custom_validators
      field :webhooks
      field :connections

      field :_id
      field :created_at
      #field :creator
      field :updated_at
      #field :updater
    end
    fields :image, :name, :flows, :connection_roles, :translators, :events, :libraries, :custom_validators, :webhooks, :connections
  end

  config.model Setup::CustomValidator do
    visible false
  end

  config.model Setup::Integration do
    edit do
      field :name
      field :pull_connection
      field :pull_event do
        inline_add { false }
        inline_edit { false }
      end
      field :data_type
      field :receiver_connection
    end
    show do
      field :name
      field :pull_connection
      field :pull_flow
      field :pull_event
      field :pull_translator
      field :data_type
      field :send_translator
      field :send_flow
      field :receiver_connection
    end
    fields :name, :pull_connection, :pull_flow, :pull_event, :pull_translator, :data_type, :send_translator, :send_flow, :receiver_connection
  end
end

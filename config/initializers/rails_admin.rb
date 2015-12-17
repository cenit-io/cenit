[RailsAdmin::Config::Actions::MemoryUsage,
 RailsAdmin::Config::Actions::DiskUsage,
 RailsAdmin::Config::Actions::SendToFlow,
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
 RailsAdmin::Config::Actions::DeleteLibrary,
 RailsAdmin::Config::Actions::SimpleShare,
 RailsAdmin::Config::Actions::BulkShare,
 RailsAdmin::Config::Actions::Pull,
 RailsAdmin::Config::Actions::RetryTask,
 RailsAdmin::Config::Actions::UploadFile,
 RailsAdmin::Config::Actions::DownloadFile,
 RailsAdmin::Config::Actions::ProcessFlow,
 RailsAdmin::Config::Actions::BuildGem,
 RailsAdmin::Config::Actions::Run,
 RailsAdmin::Config::Actions::Authorize,
 RailsAdmin::Config::Actions::SimpleDeleteDataType,
 RailsAdmin::Config::Actions::BulkDeleteDataType,
 RailsAdmin::Config::Actions::SimpleGenerate,
 RailsAdmin::Config::Actions::BulkGenerate,
 RailsAdmin::Config::Actions::SimpleExpand,
 RailsAdmin::Config::Actions::BulkExpand,
 RailsAdmin::Config::Actions::Records,
 RailsAdmin::Config::Actions::SwitchScheduler,
 RailsAdmin::Config::Actions::SimpleExport,
 RailsAdmin::Config::Actions::Schedule].each { |a| RailsAdmin::Config::Actions.register(a) }

RailsAdmin::Config::Actions.register(:export, RailsAdmin::Config::Actions::BulkExport)
RailsAdmin::Config::Fields::Types.register(RailsAdmin::Config::Fields::Types::JsonValue)
RailsAdmin::Config::Fields::Types.register(RailsAdmin::Config::Fields::Types::JsonSchema)
RailsAdmin::Config::Fields::Types.register(RailsAdmin::Config::Fields::Types::StorageFile)
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

  ### More at https://github.com/sferik/rails_admin/wiki/Base-configuration
  config.authenticate_with do
    warden.authenticate! scope: :user
  end
  config.current_user_method { current_user }
  config.audit_with :mongoid_audit
  config.authorize_with :cancan

  config.excluded_models << Setup::BaseOauthAuthorization

  config.actions do
    dashboard # mandatory
    # memory_usage
    # disk_usage
    index # mandatory
    new { except [Setup::Event, Setup::DataType, Setup::Authorization, Setup::BaseOauthProvider] }
    import
    import_schema
    translator_update
    convert
    export
    bulk_delete
    show
    run
    edit
    simple_share
    bulk_share
    build_gem
    pull
    upload_file
    download_file
    load_model
    shutdown_model
    process_flow
    authorize
    simple_generate
    bulk_generate
    simple_expand
    bulk_expand
    records
    switch_navigation
    switch_scheduler
    simple_export
    schedule
    retry_task
    simple_delete_data_type
    bulk_delete_data_type
    delete
    delete_library
    #show_in_app
    send_to_flow
    delete_all
    data_type

    # history_index do
    #   only [Setup::DataType, Setup::Webhook, Setup::Flow, Setup::Schema, Setup::Event, Setup::Connection, Setup::ConnectionRole, Setup::Library]
    # end
    # history_show do
    #   only [Setup::DataType, Setup::Webhook, Setup::Flow, Setup::Schema, Setup::Event, Setup::Connection, Setup::ConnectionRole, Setup::Notification, Setup::Library]
    # end
  end

  config.model Setup::Validator do
    visible false
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
      field :data_types

      field :_id
      field :created_at
      #field :creator
      field :updated_at
      #field :updater
    end

    fields :name, :slug, :schemas, :data_types
  end

  config.model Setup::Schema do
    object_label_method { :custom_title }
    navigation_label 'Data Definitions'
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
          {cols: '74', rows: '15'}
        end
      end

      field :schema_data_type do
        inline_edit false
        inline_add false
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
          "<pre>#{pretty_value}</pre>".html_safe
        end
      end
      field :schema_data_type

      field :_id
      field :created_at
      #field :creator
      field :updated_at
      #field :updater

    end
    fields :library, :uri, :schema_data_type
  end

  config.model Setup::DataType do
    label 'Data type'
    label_plural 'Data types'
    object_label_method { :custom_title }
    navigation_label 'Data Definitions'
    weight -17

    group :behavior do
      label 'Behavior'
      active false
    end

    configure :title do
      pretty_value do
        bindings[:object].custom_title
      end
    end

    configure :slug

    configure :storage_size, :decimal do
      pretty_value do
        unless max = bindings[:controller].instance_variable_get(:@max_storage_size)
          bindings[:controller].instance_variable_set(:@max_storage_size, max = bindings[:controller].instance_variable_get(:@objects).collect { |data_type| data_type.storage_size }.max)
        end
        (bindings[:view].render partial: 'used_memory_bar', locals: {max: max, value: bindings[:object].records_model.storage_size}).html_safe
      end
      read_only true
    end

    configure :before_save_callbacks do
      group :behavior
      inline_add false
      associated_collection_scope do
        Proc.new { |scope|
          scope.where(:parameters.with_size => 1)
        }
      end
    end

    configure :records_methods do
      group :behavior
      inline_add false
    end

    configure :data_type_methods do
      group :behavior
      inline_add false
    end

    edit do
      field :title
      field :before_save_callbacks
      field :records_methods
      field :data_type_methods
    end

    list do
      field :title
      field :name
      field :slug
      field :used_memory do
        visible { Cenit.dynamic_model_loading? }
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
      field :name
      field :slug
      field :activated
      field :schema do
        pretty_value do
          pretty_value =
            if json = JSON.pretty_generate(value) rescue nil
              "<code class='json'>#{json}</code>"
            else
              value
            end
          "<pre>#{pretty_value}</pre>".html_safe
        end
      end

      field :_id
      field :created_at
      #field :creator
      field :updated_at
      #field :updater
    end
    fields :title, :name, :used_memory
  end

  config.model Setup::EdiValidator do
    object_label_method { :custom_title }
    label 'EDI Validators'
    navigation_label 'Data Definitions'

    fields :namespace, :name, :schema_data_type, :content_type
  end

  config.model Setup::AlgorithmValidator do
    object_label_method { :custom_title }
    navigation_label 'Data Definitions'

    fields :namespace, :name, :algorithm
  end

  config.model Setup::FileDataType do
    object_label_method { :custom_title }
    group :content do
      label 'Content'
    end

    group :behavior do
      label 'Behavior'
      active false
    end

    configure :title do
      pretty_value do
        bindings[:object].custom_title
      end
    end

    configure :library do
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
    configure :used_memory do
      pretty_value do
        unless max = bindings[:controller].instance_variable_get(:@max_used_memory)
          bindings[:controller].instance_variable_set(:@max_used_memory, max = Setup::SchemaDataType.fields[:used_memory.to_s].type.new(Setup::SchemaDataType.max(:used_memory)))
        end
        (bindings[:view].render partial: 'used_memory_bar', locals: {max: max, value: Setup::SchemaDataType.fields[:used_memory.to_s].type.new(value)}).html_safe
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

    configure :validators do
      group :content
      inline_add false
    end

    configure :schema_data_type do
      group :content
      inline_add false
      inline_edit false
    end

    configure :before_save_callbacks do
      group :behavior
      inline_add false
      associated_collection_scope do
        Proc.new { |scope|
          scope.where(:parameters.with_size => 1)
        }
      end
    end

    configure :records_methods do
      group :behavior
      inline_add false
    end

    configure :data_type_methods do
      group :behavior
      inline_add false
    end

    edit do
      field :library
      field :title
      field :name
      field :slug
      field :validators
      field :schema_data_type
      field :before_save_callbacks
      field :records_methods
      field :data_type_methods
    end

    list do
      field :title
      field :name
      field :slug
      field :validators
      field :schema_data_type
      field :used_memory do
        visible { Cenit.dynamic_model_loading? }
        pretty_value do
          unless max = bindings[:controller].instance_variable_get(:@max_used_memory)
            bindings[:controller].instance_variable_set(:@max_used_memory, max = Setup::SchemaDataType.fields[:used_memory.to_s].type.new(Setup::SchemaDataType.max(:used_memory)))
          end
          (bindings[:view].render partial: 'used_memory_bar', locals: {max: max, value: Setup::SchemaDataType.fields[:used_memory.to_s].type.new(value)}).html_safe
        end
      end
      field :storage_size
    end

    show do
      field :title
      field :name
      field :slug
      field :activated
      field :validators
      field :schema_data_type

      field :_id
      field :created_at
      #field :creator
      field :updated_at
      #field :updater
    end
  end

  config.model Setup::SchemaDataType do
    group :behavior do
      label 'Behavior'
      active false
    end

    object_label_method { :custom_title }
    navigation_label 'Data Definitions'
    weight -17
    register_instance_option(:after_form_partials) do
      %w(shutdown_and_reload)
    end

    configure :title

    configure :name do
      read_only { !bindings[:object].new_record? }
    end

    configure :schema, :code_mirror do
      html_attributes do
        report = bindings[:object].shutdown(report_only: true)
        reload = (report[:reloaded].collect(&:data_type) + report[:destroyed].collect(&:data_type)).uniq
        bindings[:object].instance_variable_set(:@_to_reload, reload)
        {cols: '74', rows: '15'}
      end
      # pretty_value do
      #   "<pre><code class='json'>#{JSON.pretty_generate(value)}</code></pre>".html_safe
      # end
    end

    configure :storage_size, :decimal do
      pretty_value do
        unless max = bindings[:controller].instance_variable_get(:@max_storage_size)
          bindings[:controller].instance_variable_set(:@max_storage_size, max = bindings[:controller].instance_variable_get(:@objects).collect { |data_type| data_type.records_model.storage_size }.max)
        end
        (bindings[:view].render partial: 'used_memory_bar', locals: {max: max, value: bindings[:object].records_model.storage_size}).html_safe
      end
    end

    configure :before_save_callbacks do
      group :behavior
      inline_add false
      associated_collection_scope do
        Proc.new { |scope|
          scope.where(:parameters.with_size => 1)
        }
      end
    end

    configure :records_methods do
      group :behavior
      inline_add false
    end

    configure :data_type_methods do
      group :behavior
      inline_add false
    end

    edit do
      field :library
      field :title
      field :name
      field :slug
      field :schema, :json_schema do
        help { 'Required' }
      end
      field :before_save_callbacks
      field :records_methods
      field :data_type_methods
    end

    list do
      field :library
      field :title
      field :name
      field :slug
      field :used_memory do
        visible { Cenit.dynamic_model_loading? }
        pretty_value do
          unless max = bindings[:controller].instance_variable_get(:@max_used_memory)
            bindings[:controller].instance_variable_set(:@max_used_memory, max = Setup::SchemaDataType.fields[:used_memory.to_s].type.new(Setup::SchemaDataType.max(:used_memory)))
          end
          (bindings[:view].render partial: 'used_memory_bar', locals: {max: max, value: Setup::SchemaDataType.fields[:used_memory.to_s].type.new(value)}).html_safe
        end
      end
      field :storage_size
    end

    show do
      field :library
      field :title
      field :name
      field :slug
      field :activated
      field :schema do
        pretty_value do
          "<pre><code class='ruby'>#{JSON.pretty_generate(value)}</code></pre>".html_safe
        end
      end

      field :_id
      field :created_at
      #field :creator
      field :updated_at
      #field :updater
    end
  end

  config.model Setup::Connection do
    object_label_method { :custom_title }
    weight -15

    group :credentials do
      label 'Credentials'
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

    configure :authorization do
      group :credentials
      inline_edit false
      visible { bindings[:view]._current_user.has_role? :admin }
    end

    configure :authorization_handler do
      group :credentials
      visible { bindings[:view]._current_user.has_role? :admin }
    end

    group :parameters do
      label 'Parameters & Headers'
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
      field :namespace
      field :name
      field :url

      field :key
      field :token
      field :authorization
      field :authorization_handler

      field :parameters
      field :headers
      field :template_parameters

      field :_id
      field :created_at
      #field :creator
      field :updated_at
      #field :updater
    end

    fields :namespace, :name, :url, :key, :token, :authorization, :authorization_handler, :parameters, :headers, :template_parameters
  end

  config.model Setup::Parameter do
    object_label_method { :to_s }
    edit do
      field :key
      field :value
    end
  end

  config.model Setup::ConnectionRole do
    object_label_method { :custom_title }
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
      field :namespace
      field :name
      field :webhooks
      field :connections
    end
    show do
      field :namespace
      field :name
      field :webhooks
      field :connections

      field :_id
      field :created_at
      #field :creator
      field :updated_at
      #field :updater
    end
    fields :namespace, :name, :webhooks, :connections
  end

  config.model Setup::Webhook do
    object_label_method { :custom_title }
    weight -13

    group :credentials do
      label 'Credentials'
    end

    configure :authorization do
      group :credentials
      inline_edit false
      visible { bindings[:view]._current_user.has_role? :admin }
    end

    configure :authorization_handler do
      group :credentials
      visible { bindings[:view]._current_user.has_role? :admin }
    end

    group :parameters do
      label 'Parameters & Headers'
    end

    configure :path, :string do
      help 'Requiered. Path of the webhook relative to connection URL.'
      html_attributes do
        {maxlength: 255, size: 100}
      end
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
      field :namespace
      field :name
      field :path
      field :method

      field :authorization
      field :authorization_handler

      field :parameters
      field :headers
      field :template_parameters

      field :_id
      field :created_at
      #field :creator
      field :updated_at
      #field :updater
    end
    fields :namespace, :name, :path, :method, :authorization, :authorization_handler, :parameters, :headers, :template_parameters
  end

  config.model Setup::Task do
    navigation_label 'Monitor'
    object_label_method { :to_s }
    configure :attempts_succeded, :text do
      label 'Attempts/Succedded'
    end
    edit do
      field :description
    end
    fields :description, :scheduler, :attempts_succeded, :retries, :progress, :status, :notifications
  end

  config.model Setup::FlowExecution do
    navigation_label 'Monitor'
    object_label_method { :to_s }
    configure :attempts_succeded, :text do
      label 'Attempts/Succedded'
    end
    edit do
      field :description
    end
    fields :flow, :description, :scheduler, :attempts_succeded, :retries, :progress, :status, :notifications
  end

  config.model Setup::DataTypeGeneration do
    navigation_label 'Monitor'
    object_label_method { :to_s }
    configure :attempts_succeded, :text do
      label 'Attempts/Succedded'
    end
    edit do
      field :description
    end
    fields :description, :scheduler, :attempts_succeded, :retries, :progress, :status, :notifications
  end

  config.model Setup::DataTypeExpansion do
    navigation_label 'Monitor'
    object_label_method { :to_s }
    configure :attempts_succeded, :text do
      label 'Attempts/Succedded'
    end
    edit do
      field :description
    end
    fields :description, :scheduler, :attempts_succeded, :retries, :progress, :status, :notifications
  end

  config.model Setup::Translation do
    navigation_label 'Monitor'
    object_label_method { :to_s }
    configure :attempts_succeded, :text do
      label 'Attempts/Succedded'
    end
    edit do
      field :description
    end
    fields :translator, :description, :scheduler, :attempts_succeded, :retries, :progress, :status, :notifications
  end

  config.model Setup::DataImport do
    navigation_label 'Monitor'
    object_label_method { :to_s }
    configure :attempts_succeded, :text do
      label 'Attempts/Succedded'
    end
    fields :translator, :data, :description, :scheduler, :attempts_succeded, :retries, :progress, :status, :notifications
  end

  config.model Setup::SchemasImport do
    navigation_label 'Monitor'
    object_label_method { :to_s }
    configure :attempts_succeded, :text do
      label 'Attempts/Succedded'
    end
    edit do
      field :description
    end
    fields :library, :base_uri, :data, :description, :scheduler, :attempts_succeded, :retries, :progress, :status, :notifications
  end

  config.model Setup::Deletion do
    navigation_label 'Monitor'
    object_label_method { :to_s }
    configure :attempts_succeded, :text do
      label 'Attempts/Succedded'
    end
    configure :deletion_model do
      label 'Model'
      pretty_value do
        if value
          v = bindings[:view]
          amc = RailsAdmin.config(value)
          am = amc.abstract_model
          wording = amc.navigation_label + ' > ' + amc.label
          can_see = !am.embedded? && (index_action = v.action(:index, am))
          (can_see ? v.link_to(amc.contextualized_label(:menu), v.url_for(action: index_action.action_name, model_name: am.to_param), class: 'pjax') : wording).html_safe
        end
      end
    end
    edit do
      field :description
    end
    fields :deletion_model, :description, :scheduler, :attempts_succeded, :retries, :progress, :status, :notifications
  end

  config.model Setup::AlgorithmExecution do
    navigation_label 'Monitor'
    object_label_method { :to_s }
    configure :attempts_succeded, :text do
      label 'Attempts/Succedded'
    end
    edit do
      field :description
    end
    fields :algorithm, :description, :scheduler, :attempts_succeded, :retries, :progress, :status, :notifications
  end

  config.model Setup::Notification do
    navigation_label 'Monitor'
    object_label_method { :label }

    configure :created_at

    configure :type do
      pretty_value do
        color =
          case bindings[:object].type
          when :info
            'green'
          when :notice
            'blue'
          when :warning
            'orange'
          else
            'red'
          end
        "<label style='color:#{color}'>#{value.to_s.capitalize}</label>".html_safe
      end
    end

    configure :message do
      pretty_value do
        color =
          case bindings[:object].type
          when :info
            'green'
          when :notice
            'blue'
          when :warning
            'orange'
          else
            'red'
          end
        "<label style='color:#{color}'>#{value}</label>".html_safe
      end
    end

    configure :attachment, :storage_file

    fields :created_at, :type, :message, :attachment, :task
  end

  config.model Setup::Flow do
    object_label_method { :custom_title }
    register_instance_option(:form_synchronized) do
      [:custom_data_type, :data_type_scope, :scope_filter, :scope_evaluator, :lot_size, :connection_role, :webhook, :response_translator, :response_data_type]
    end
    edit do
      field :namespace
      field :name
      field :event do
        inline_edit false
        inline_add false
      end
      field :translator do
        help 'Required'
      end
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
      field :scope_evaluator do
        inline_add false
        inline_edit false
        visible { bindings[:object].scope_symbol == :evaluation }
        associated_collection_scope do
          Proc.new { |scope|
            scope.where(:parameters.with_size => 1)
          }
        end
        help 'Required'
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
        visible { (((obj = bindings[:object]).translator && obj.translator.type == :Import) || obj.response_translator.present?) && bindings[:object].ready_to_save? }
        help "Events won't be fired for created or updated records if checked"
      end
      field :active do
        visible { bindings[:object].ready_to_save? }
      end
      field :notify_request do
        visible { bindings[:object].ready_to_save? }
        help 'Track request via notifications if checked'
      end
      field :notify_response do
        visible { bindings[:object].ready_to_save? }
        help 'Track responses via notification if checked'
      end
    end

    show do
      field :namespace
      field :name
      field :active
      field :event
      field :translator

      field :_id
      field :created_at
      #field :creator
      field :updated_at
      #field :updater
    end

    fields :namespace, :name, :active, :event, :translator
  end

  config.model Setup::Event do
    object_label_method { :custom_title }
    edit do
      field :namespace
      field :name
    end

    show do
      field :namespace
      field :name

      field :_id
      field :created_at
      #field :creator
      field :updated_at
      #field :updater
    end

    fields :namespace, :name
  end

  config.model Setup::Observer do
    object_label_method { :custom_title }
    edit do
      field :namespace
      field :name
      field :data_type do
        inline_add false
        inline_edit false
        associated_collection_scope do
          data_type = bindings[:object].data_type
          Proc.new { |scope|
            if data_type
              scope.where(id: data_type.id)
            else
              scope
            end
          }
        end
        help 'Required'
      end
      field :trigger_evaluator do
        visible { (obj = bindings[:object]).data_type.blank? || obj.trigger_evaluator.present? || obj.triggers.nil? }
        associated_collection_scope do
          Proc.new { |scope|
            scope.all.or(:parameters.with_size => 1).or(:parameters.with_size => 2)
          }
        end
      end
      field :triggers do
        visible do
          bindings[:controller].instance_variable_set(:@_data_type, data_type = bindings[:object].data_type)
          bindings[:controller].instance_variable_set(:@_update_field, 'data_type_id')
          data_type.present? && !bindings[:object].trigger_evaluator.present?
        end
        partial 'form_triggers'
        help false
      end
    end

    show do
      field :namespace
      field :name
      field :data_type
      field :triggers
      field :trigger_evaluator

      field :_id
      field :created_at
      #field :creator
      field :updated_at
      #field :updater
    end

    fields :namespace, :name, :data_type, :triggers, :trigger_evaluator
  end

  config.model Setup::Scheduler do
    object_label_method { :custom_title }
    edit do
      field :namespace
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
      field :namespace
      field :name
      field :expression

      field :_id
      field :created_at
      #field :creator
      field :updated_at
      #field :updater
    end

    fields :namespace, :name, :scheduling_method, :expression, :activated
  end

  config.model Setup::Translator do
    object_label_method { :custom_title }
    register_instance_option(:form_synchronized) do
      [:source_data_type, :target_data_type, :transformation, :target_importer, :source_exporter, :discard_chained_records]
    end
    edit do
      field :namespace
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
        help 'Required'
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

      field :source_handler do
        visible { (t = bindings[:object]).style.present? && (t.type == :Update || (t.type == :Conversion && t.style == 'ruby')) }
        help { 'Handle sources on transformation' }
      end

      field :transformation, :code_mirror do
        visible { bindings[:object].style.present? && bindings[:object].style != 'chain' }
        help { 'Required' }
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
      field :namespace
      field :name
      field :type
      field :source_data_type
      field :bulk_source
      field :target_data_type
      field :discard_events
      field :style
      field :mime_type
      field :file_extension
      field :transformation do
        pretty_value do
          "<pre><code class='ruby'>#{value}</code></pre>".html_safe
        end
      end
      field :source_exporter
      field :target_importer
      field :discard_chained_records

      field :_id
      field :created_at
      #field :creator
      field :updated_at
      #field :updater
    end

    fields :namespace, :name, :type, :style, :transformation
  end

  config.model Setup::SharedName do
    visible { false }
    navigation_label 'Collections'
    fields :name, :owners
  end

  config.model Script do
    navigation_label 'Administration'

    configure :code, :code_mirror do
      help { 'Required' }
      pretty_value do
        "<pre><code class='ruby'>#{value}</code></pre>".html_safe
      end
    end

    fields :name, :description, :code
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
      field :name do
        required { true }
      end
      field :shared_version do
        required { true }
      end
      field :authors
      field :summary
      field :description
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
          !bindings[:object].instance_variable_get(:@_selecting_dependencies)
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
      field :summary
      field :description
      field :authors
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
      field :authors
      field :summary
      field :dependencies
    end
  end

  config.model Setup::CollectionAuthor do
    object_label_method { :label }
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

  config.model Setup::CollectionData do
    object_label_method { :label }
  end

  config.model Setup::Collection do
    navigation_label 'Collections'
    weight -19

    group :setup do
      label 'Setup objects'
      active true
    end

    group :data do
      label 'Data'
      active false
    end

    configure :flows do
      group :setup
    end

    configure :connection_roles do
      group :setup
    end

    configure :translators do
      group :setup
    end

    configure :events do
      group :setup
    end

    configure :libraries do
      group :setup
    end

    configure :custom_validators do
      group :setup
    end

    configure :algorithms do
      group :setup
    end

    configure :webhooks do
      group :setup
    end

    configure :connections do
      group :setup
    end

    configure :authorizations do
      group :setup
    end

    configure :oauth_providers do
      group :setup
    end

    configure :oauth_clients do
      group :setup
    end

    configure :oauth2_scopes do
      group :setup
    end

    configure :data do
      group :data
    end

    show do
      field :image
      field :name
      field :flows
      field :connection_roles
      field :translators
      field :events
      field :libraries
      field :custom_validators
      field :algorithms
      field :webhooks
      field :connections
      field :authorizations
      field :oauth_providers
      field :oauth_clients
      field :oauth2_scopes
      field :data

      field :_id
      field :created_at
      #field :creator
      field :updated_at
      #field :updater
    end
    fields :image, :name, :flows, :connection_roles, :translators, :events, :libraries, :custom_validators, :algorithms, :webhooks, :connections, :authorizations, :oauth_providers, :oauth_clients, :oauth2_scopes, :data
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

  config.model Setup::Algorithm do
    object_label_method { :custom_title }
    edit do
      field :namespace
      field :name
      field :description
      field :parameters
      field :code, :code_mirror do
        help { 'Required' }
      end
      field :call_links do
        visible { bindings[:object].call_links.present? }
      end
    end
    show do
      field :namespace
      field :name
      field :description
      field :parameters
      field :code do
        pretty_value do
          "<pre><code class='ruby'>#{value}</code></pre>".html_safe
        end
      end
      field :_id
    end
    fields :namespace, :name, :description, :parameters, :call_links
  end

  config.model Setup::CallLink do
    edit do
      field :name do
        read_only true
        help { nil }
        label 'Call name'
      end
      field :link do
        inline_add false
        inline_edit false
        help { nil }
      end
    end
    fields :name, :link
  end

  config.model Role do
    navigation_label 'Administration'
    fields :name, :users
  end

  config.model User do
    navigation_label 'Administration'
    object_label_method { :label }

    group :credentials do
      label 'Credentials'
      active true
    end

    group :activity do
      label 'Activity'
      active true
    end

    configure :name
    configure :email
    configure :roles
    configure :account do
      read_only { true }
    end
    configure :password do
      group :credentials
    end
    configure :password_confirmation do
      group :credentials
    end
    configure :key do
      group :credentials
    end
    configure :authentication_token do
      group :credentials
    end
    configure :confirmed_at do
      group :activity
    end
    configure :sign_in_count do
      group :activity
    end
    configure :current_sign_in_at do
      group :activity
    end
    configure :last_sign_in_at do
      group :activity
    end
    configure :current_sign_in_ip do
      group :activity
    end
    configure :last_sign_in_ip do
      group :activity
    end

    edit do
      field :picture
      field :name
      field :email do
        visible { Account.current.super_admin? }
      end
      field :roles do
        visible { Account.current.super_admin? }
      end
      field :account do
        label { Account.current.super_admin? ? 'Account' : 'Account settings' }
        help { nil }
      end
      field :password do
        visible { Account.current.super_admin? }
      end
      field :password_confirmation do
        visible { Account.current.super_admin? }
      end
      field :key do
        visible { !bindings[:object].new_record? && Account.current.super_admin? }
      end
      field :authentication_token do
        visible { !bindings[:object].new_record? && Account.current.super_admin? }
      end
      field :confirmed_at do
        visible { !bindings[:object].new_record? && Account.current.super_admin? }
      end
      field :sign_in_count do
        visible { !bindings[:object].new_record? && Account.current.super_admin? }
      end
      field :current_sign_in_at do
        visible { !bindings[:object].new_record? && Account.current.super_admin? }
      end
      field :last_sign_in_at do
        visible { !bindings[:object].new_record? && Account.current.super_admin? }
      end
      field :current_sign_in_ip do
        visible { !bindings[:object].new_record? && Account.current.super_admin? }
      end
      field :last_sign_in_ip do
        visible { !bindings[:object].new_record? && Account.current.super_admin? }
      end
    end

    show do
      field :picture
      field :name
      field :email
      field :account
      field :roles
      field :key
      field :authentication_token
      field :sign_in_count
      field :current_sign_in_at
      field :last_sign_in_at
      field :current_sign_in_ip
      field :last_sign_in_ip
    end

    fields :picture, :name, :email, :account, :roles, :key, :authentication_token, :authentication_token, :sign_in_count, :current_sign_in_at, :last_sign_in_at, :current_sign_in_ip, :last_sign_in_ip
  end

  config.model Account do
    navigation_label 'Administration'
    object_label_method { :label }

    configure :_id do
      visible { Account.current.super_admin? }
    end
    configure :name do
      visible { Account.current.super_admin? }
    end
    configure :owner do
      read_only { !Account.current.super_admin? }
      help { nil }
    end
    configure :tenant_account do
      visible { Account.current.super_admin? }
    end
    configure :number do
      visible { Account.current.super_admin? }
    end
    configure :users do
      visible { Account.current.super_admin? }
    end
    configure :notification_level


    fields :_id, :name, :owner, :tenant_account, :number, :users, :notification_level
  end

  config.model Setup::SharedName do
    navigation_label 'Administration'

    fields :name, :owners
  end

  config.model Script do
    navigation_label 'Administration'

    edit do
      field :name
      field :description
      field :code, :code_mirror
    end

    show do
      field :name
      field :description
      field :code do
        pretty_value do
          "<pre><code class='ruby'>#{value}</code></pre>".html_safe
        end
      end
    end

    fields :name, :description, :code
  end

  config.model CenitToken do
    navigation_label 'Administration'
  end

  config.model Setup::BaseOauthProvider do
    object_label_method { :custom_title }
    label 'Provider'
    navigation_label 'OAuth'

    configure :tenant do
      visible { Account.current.super_admin? }
      read_only { true }
      help ''
    end

    configure :shared do
      visible { Account.current.super_admin? }
    end

    fields :namespace, :name, :response_type, :authorization_endpoint, :token_endpoint, :token_method, :parameters, :clients, :tenant, :shared
  end

  config.model Setup::OauthProvider do
    object_label_method { :custom_title }

    configure :tenant do
      visible { Account.current.super_admin? }
      read_only { true }
      help ''
    end

    configure :shared do
      visible { Account.current.super_admin? }
    end

    fields :namespace, :name, :response_type, :authorization_endpoint, :token_endpoint, :token_method, :request_token_endpoint, :parameters, :tenant, :shared
  end

  config.model Setup::Oauth2Provider do
    object_label_method { :custom_title }

    configure :tenant do
      visible { Account.current.super_admin? }
      read_only { true }
      help ''
    end

    configure :shared do
      visible { Account.current.super_admin? }
    end

    fields :namespace, :name, :response_type, :authorization_endpoint, :token_endpoint, :token_method, :parameters, :scope_separator, :tenant, :shared
  end

  config.model Setup::OauthParameter do
    navigation_label 'OAuth'
    object_label_method { :to_s }
    fields :key, :value
  end

  config.model Setup::OauthClient do
    object_label_method { :custom_title }
    navigation_label 'OAuth'

    configure :tenant do
      visible { Account.current.super_admin? }
      read_only { true }
      help ''
    end

    configure :shared do
      visible { Account.current.super_admin? }
    end

    configure :identifier do
      pretty_value do
        if Account.current.super_admin? || Account.current.users.collect(&:id).include?(bindings[:object].creator_id)
          value
        else
          '<i class="icon-lock"/>'.html_safe
        end
      end
    end

    configure :secret do
      pretty_value do
        if Account.current.super_admin? || Account.current.users.collect(&:id).include?(bindings[:object].creator_id)
          value
        else
          '<i class="icon-lock"/>'.html_safe
        end
      end
    end

    fields :namespace, :name, :provider, :identifier, :secret, :tenant, :shared
  end

  config.model Setup::Oauth2Scope do
    object_label_method { :custom_title }
    navigation_label 'OAuth'

    configure :tenant do
      visible { Account.current.super_admin? }
      read_only { true }
      help ''
    end

    configure :shared do
      visible { Account.current.super_admin? }
    end

    fields :provider, :name, :description, :tenant, :shared
  end

  config.model Setup::Authorization do
    fields :namespace, :name
  end

  config.model Setup::OauthAuthorization do
    parent Setup::Authorization

    edit do
      field :namespace
      field :name
      field :provider do
        inline_add false
        inline_edit false
        associated_collection_scope do
          provider = (obj = bindings[:object]) && obj.provider
          Proc.new { |scope|
            if provider
              scope.any_in(id: provider.id)
            else
              scope.any_in(_type: Setup::OauthProvider.to_s)
            end
          }
        end
      end
      field :client do
        inline_add false
        inline_edit false
        visible do
          if ((obj = bindings[:object]) && obj.provider).present?
            obj.client = obj.provider.clients.first if obj.client.blank?
            true
          else
            false
          end
        end
        associated_collection_scope do
          provider = ((obj = bindings[:object]) && obj.provider) || nil
          Proc.new { |scope|
            if provider
              scope.where(provider_id: provider.id)
            else
              scope
            end
          }
        end
      end
    end

    group :credentials do
      label 'Credentials'
    end

    configure :access_token do
      group :credentials
    end

    configure :token_span do
      group :credentials
    end

    configure :authorized_at do
      group :credentials
    end

    configure :access_token_secret do
      group :credentials
    end

    configure :realm do
      group :credentials
    end

    show do
      field :namespace
      field :name
      field :provider
      field :client

      field :access_token
      field :access_token_secret
      field :realm
      field :token_span
      field :authorized_at
    end

    fields :namespace, :name, :provider, :client
  end

  config.model Setup::Oauth2Authorization do
    parent Setup::Authorization

    edit do
      field :namespace
      field :name
      field :provider do
        inline_add false
        inline_edit false
        associated_collection_scope do
          provider = (obj = bindings[:object]) && obj.provider
          Proc.new { |scope|
            if provider
              scope.any_in(id: provider.id)
            else
              scope.any_in(_type: Setup::Oauth2Provider.to_s)
            end
          }
        end
      end
      field :client do
        inline_add false
        inline_edit false
        visible do
          if ((obj = bindings[:object]) && obj.provider).present?
            obj.client = obj.provider.clients.first if obj.client.blank?
            true
          else
            false
          end
        end
        associated_collection_scope do
          provider = ((obj = bindings[:object]) && obj.provider) || nil
          Proc.new { |scope|
            if provider
              scope.where(provider_id: provider.id)
            else
              scope
            end
          }
        end
      end
      field :scopes do
        visible { ((obj = bindings[:object]) && obj.provider).present? }
        associated_collection_scope do
          provider = ((obj = bindings[:object]) && obj.provider) || nil
          Proc.new { |scope|
            if provider
              scope.where(provider_id: provider.id)
            else
              scope
            end
          }
        end
      end
    end

    group :credentials do
      label 'Credentials'
    end

    configure :access_token do
      group :credentials
    end

    configure :token_span do
      group :credentials
    end

    configure :authorized_at do
      group :credentials
    end

    configure :refresh_token do
      group :credentials
    end

    configure :token_type do
      group :credentials
    end

    show do
      field :namespace
      field :name
      field :provider
      field :client
      field :scopes

      field :token_type
      field :access_token
      field :token_span
      field :authorized_at
    end

    fields :namespace, :name, :provider, :client, :scopes
  end

  config.model Setup::Raml do
    configure :raml_references do
      visible { bindings[:view]._current_user.has_role? :admin }
    end

    show do
      field :api_name
      field :api_version
      field :repo
      field :raml_doc
      field :raml_references
    end

    edit do
      field :api_name
      field :api_version
      field :repo
      field :raml_doc
      field :raml_references
    end

    fields :api_name, :api_version, :repo, :raml_doc, :raml_references
  end

  config.model Setup::RamlReference do
    object_label_method { :to_s }
    edit do
      field :path
      field :content
    end
    fields :path, :content
  end

  config.model Setup::Storage do
    object_label_method { :label }

    configure :filename do
      label 'File name'
      pretty_value { bindings[:object].storage_name }
    end

    configure :length do
      label 'Size'
      pretty_value do
        unless max = bindings[:controller].instance_variable_get(:@max_length)
          bindings[:controller].instance_variable_set(:@max_length, max = bindings[:controller].instance_variable_get(:@objects).collect { |storage| storage.length }.max)
        end
        (bindings[:view].render partial: 'used_memory_bar', locals: {max: max, value: bindings[:object].length}).html_safe
      end
    end

    configure :storer_model do
      label 'Model'
      pretty_value do
        if value
          v = bindings[:view]
          amc = RailsAdmin.config(value)
          am = amc.abstract_model
          wording = amc.navigation_label + ' > ' + amc.label
          can_see = !am.embedded? && (index_action = v.action(:index, am))
          (can_see ? v.link_to(amc.label, v.url_for(action: index_action.action_name, model_name: am.to_param), class: 'pjax') : wording).html_safe
        end
      end
    end

    configure :storer_object do
      label 'Object'
      pretty_value do
        if value
          v = bindings[:view]
          amc = RailsAdmin.config(value.class)
          am = amc.abstract_model
          wording = value.send(amc.object_label_method)
          can_see = !am.embedded? && (show_action = v.action(:show, am, value))
          (can_see ? v.link_to(wording, v.url_for(action: show_action.action_name, model_name: am.to_param, id: value.id), class: 'pjax') : wording).html_safe
        end
      end
    end

    configure :storer_property do
      label 'Property'
    end

    configure :chunks

    fields :storer_model, :storer_object, :storer_property, :filename, :contentType, :length, :chunks
  end

  config.model Setup::DelayedMessage do
    navigation_label 'Administration'
  end

  config.model Setup::SystemNotification do
    navigation_label 'Administration'
  end

end

[
  RailsAdmin::Config::Actions::DiskUsage,
  RailsAdmin::Config::Actions::SendToFlow,
  RailsAdmin::Config::Actions::SwitchNavigation,
  RailsAdmin::Config::Actions::DataType,
  RailsAdmin::Config::Actions::Import,
  #RailsAdmin::Config::Actions::EdiExport,
  RailsAdmin::Config::Actions::ImportSchema,
  RailsAdmin::Config::Actions::DeleteAll,
  RailsAdmin::Config::Actions::TranslatorUpdate,
  RailsAdmin::Config::Actions::Convert,
  RailsAdmin::Config::Actions::SimpleShare,
  RailsAdmin::Config::Actions::BulkShare,
  RailsAdmin::Config::Actions::Pull,
  RailsAdmin::Config::Actions::RetryTask,
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
  RailsAdmin::Config::Actions::Schedule,
  RailsAdmin::Config::Actions::Submit,
  RailsAdmin::Config::Actions::Trash,
  RailsAdmin::Config::Actions::Inspect,
  RailsAdmin::Config::Actions::Copy,
  RailsAdmin::Config::Actions::Cancel,
  RailsAdmin::Config::Actions::Configure,
  RailsAdmin::Config::Actions::SimpleCrossShare,
  RailsAdmin::Config::Actions::BulkCrossShare,
  RailsAdmin::Config::Actions::Regist,
  RailsAdmin::Config::Actions::SharedCollectionIndex,
  RailsAdmin::Config::Actions::BulkPull,
  RailsAdmin::Config::Actions::CleanUp,
  RailsAdmin::Config::Actions::ShowRecords,
  RailsAdmin::Config::Actions::RunScript,
  RailsAdmin::Config::Actions::Play,
  RailsAdmin::Config::Actions::PullImport,
  RailsAdmin::Config::Actions::State,
  RailsAdmin::Config::Actions::Documentation,
  RailsAdmin::Config::Actions::Push
].each { |a| RailsAdmin::Config::Actions.register(a) }

RailsAdmin::Config::Actions.register(:export, RailsAdmin::Config::Actions::BulkExport)

[
  RailsAdmin::Config::Fields::Types::JsonValue,
  RailsAdmin::Config::Fields::Types::JsonSchema,
  RailsAdmin::Config::Fields::Types::StorageFile,
  RailsAdmin::Config::Fields::Types::EnumEdit,
  RailsAdmin::Config::Fields::Types::Model,
  RailsAdmin::Config::Fields::Types::Record,
  RailsAdmin::Config::Fields::Types::HtmlErb,
  RailsAdmin::Config::Fields::Types::OptionalBelongsTo
].each { |f| RailsAdmin::Config::Fields::Types.register(f) }

RailsAdmin::Config::Fields::Types::CodeMirror.register_instance_option :js_location do
  bindings[:view].asset_path('codemirror.js')
end

RailsAdmin::Config::Fields::Types::CodeMirror.register_instance_option :css_location do
  bindings[:view].asset_path('codemirror.css')
end

RailsAdmin::Config::Fields::Types::CodeMirror.register_instance_option :config do
  {
    mode: 'css',
    theme: 'night',
  }
end

RailsAdmin::Config::Fields::Types::CodeMirror.register_instance_option :assets do
  {
    mode: bindings[:view].asset_path('codemirror/modes/css.js'),
    theme: bindings[:view].asset_path('codemirror/themes/night.css'),
  }
end

module RailsAdmin

  module Config

    class << self

      def navigation(label, options)
        navigation_options[label.to_s] = options
      end

      def navigation_options
        @nav_options ||= {}
      end
    end
  end
end

RailsAdmin.config do |config|

  config.total_columns_width = 900

  ## == PaperTrail ==
  # config.audit_with :paper_trail, 'User', 'PaperTrail::Version' # PaperTrail >= 3.0.0

  ### More at https://github.com/sferik/rails_admin/wiki/Base-configuration
  config.authenticate_with do
    warden.authenticate! scope: :user unless %w(dashboard shared_collection_index index show).include?(action_name)
  end
  config.current_user_method { current_user }
  config.audit_with :mongoid_audit
  config.authorize_with :cancan

  config.excluded_models += [Setup::BaseOauthAuthorization, Setup::AwsAuthorization]

  config.actions do
    dashboard # mandatory
    # disk_usage
    shared_collection_index
    index # mandatory
    new { except [Setup::Event, Setup::DataType, Setup::Authorization, Setup::BaseOauthProvider] }
    import
    import_schema
    pull_import
    translator_update
    convert
    export
    bulk_delete
    show
    show_records
    run
    run_script
    edit
    configure
    play
    copy
    simple_share
    bulk_share
    simple_cross_share
    bulk_cross_share
    build_gem
    pull
    bulk_pull
    push
    download_file
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
    state
    retry_task
    submit
    inspect
    cancel
    regist
    simple_delete_data_type
    bulk_delete_data_type
    delete
    trash
    clean_up
    #show_in_app
    send_to_flow
    delete_all
    data_type
    #history_index
    history_show do
      only do
        [
          Setup::Algorithm,
          Setup::Connection,
          Setup::Webhook,
          Setup::Translator,
          Setup::Flow,
          Setup::OauthClient,
          Setup::Oauth2Scope
        ] +
          Setup::DataType.class_hierarchy +
          Setup::Validator.class_hierarchy +
          Setup::BaseOauthProvider.class_hierarchy
      end
      visible { only.include?((obj = bindings[:object]).class) && obj.try(:shared?) }
    end
    documentation
  end

  def shared_read_only
    instance_eval do
      read_only { (obj = bindings[:object]).creator_id != User.current.id && obj.shared? }
    end
  end

  shared_non_editable = Proc.new do
    shared_read_only
  end

  #Collections

  config.navigation 'Collections', icon: 'fa fa-cubes'

  config.model Setup::CrossCollectionAuthor do
    visible false
    object_label_method { :label }
    fields :name, :email
  end

  config.model Setup::CrossCollectionPullParameter do
    visible false
    object_label_method { :label }
    configure :location, :json_value
    edit do
      field :label
      field :property_name
      field :location
    end
    show do
      field :label
      field :property_name
      field :location

      field :created_at
      #field :creator
      field :updated_at
    end
    fields :label, :property_name, :location
  end

  config.model Setup::CrossSharedCollection do
    weight 000
    label 'Cross Shared Collection'
    navigation_label 'Collections'
    object_label_method :versioned_name

    visible { Account.current_super_admin? }

    public_access true
    extra_associations do
      Setup::Collection.reflect_on_all_associations(:has_and_belongs_to_many).collect do |association|
        association = association.dup
        association[:name] = "data_#{association.name}".to_sym
        RailsAdmin::Adapters::Mongoid::Association.new(association, abstract_model.model)
      end
    end

    index_template_name :shared_collection_grid
    index_link_icon 'icon-th-large'

    configure :readme, :html_erb
    configure :pull_data, :json_value
    configure :data, :json_value
    configure :swagger_spec, :json_value

    group :workflows

    configure :flows do
      group :workflows
    end

    configure :events do
      group :workflows
    end

    configure :translators do
      group :workflows
    end

    configure :algorithms do
      group :workflows
    end

    configure :applications do
      group :workflows
    end

    group :api_connectors do
      label 'Connectors'
      active true
    end

    configure :connections do
      group :api_connectors
    end

    configure :webhooks do
      group :api_connectors
    end

    configure :connection_roles do
      group :api_connectors
    end

    group :data

    configure :data_types do
      group :data
    end

    configure :schemas do
      group :data
    end

    configure :data do
      group :data
    end

    configure :custom_validators do
      group :data
    end

    group :security

    configure :authorizations do
      group :security
    end

    configure :oauth_providers do
      group :security
    end

    configure :oauth_clients do
      group :security
    end

    configure :oauth2_scopes do
      group :security
    end

    group :config

    configure :namespaces do
      group :config
    end

    edit do
      field :image
      field :logo_background, :color
      field :name
      field :shared_version
      field :summary
      field :category
      field :authors
      field :pull_count
      field :pull_parameters
      field :dependencies
      field :readme
    end

    show do
      field :image
      field :name do
        pretty_value do
          bindings[:object].versioned_name
        end
      end
      field :summary
      field :readme

      field :authors
      field :pull_count
      field :_id
      field :updated_at

      field :data_schemas do
        label 'Schemas'
        group :data
      end
      field :data_custom_validators do
        label 'Validators'
        group :data
      end
      field :data_data_types do
        label 'Data Types'
        group :data
      end

      field :data_connections do
        label 'Connections'
        group :api_connectors
      end

      field :data_webhooks do
        label 'Webhooks'
        group :api_connectors
      end

      field :data_connection_roles do
        label 'Connection Roles'
        group :api_connectors
      end

      field :data_flows do
        label 'Flows'
        group :workflows
      end

      field :data_events do
        label 'Events'
        group :workflows
      end

      field :data_translators do
        label 'Translators'
        group :workflows
      end

      field :data_algorithms do
        label 'Algorithms'
        group :workflows
      end

      field :data_applications do
        label 'Applications'
        group :workflows
      end

      field :data_authorizations do
        label 'Autorizations'
        group :security
      end

      field :data_oauth_clients do
        label 'OAuth Clients'
        group :security
      end

      field :data_oauth_providers do
        label 'OAuth Providers'
        group :security
      end

      field :data_oauth2_scopes do
        label 'OAuth 2.0 Scopes'
        group :security
      end

      field :data_namespaces do
        label 'Namespaces'
        group :config
      end
    end
  end

  config.model Setup::SharedCollection do
    weight 010
    label 'Shared Collection'
    register_instance_option(:discard_submit_buttons) do
      !(a = bindings[:action]) || a.key != :edit
    end
    navigation_label 'Collections'
    object_label_method { :versioned_name }

    public_access true
    extra_associations do
      Setup::Collection.reflect_on_all_associations(:has_and_belongs_to_many).collect do |association|
        association = association.dup
        association[:name] = "data_#{association.name}".to_sym
        RailsAdmin::Adapters::Mongoid::Association.new(association, abstract_model.model)
      end
    end

    index_template_name :shared_collection_grid
    index_link_icon 'icon-th-large'

    group :collections
    group :workflows
    group :api_connectors do
      label 'Connectors'
      active true
    end
    group :data
    group :security


    edit do
      field :image do
        visible { !bindings[:object].instance_variable_get(:@sharing) }
      end
      field :logo_background
      field :name do
        required { true }
      end
      field :shared_version do
        required { true }
      end
      field :authors
      field :summary
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
          !((v = bindings[:object].instance_variable_get(:@_selecting_connections)).nil? || v)
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
          !((v = bindings[:object].instance_variable_get(:@_selecting_dependencies)).nil? || v)
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
      field :pull_parameters
      field :pull_count do
        visible { Account.current_super_admin? }
      end
      field :readme do
        visible do
          !(obj = bindings[:object]).instance_variable_get(:@_selecting_collection) &&
            !obj.instance_variable_get(:@_selecting_connections)
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
      field :summary do
        pretty_value do
          value.html_safe
        end
      end
      field :readme, :html_erb
      field :authors
      field :dependencies
      field :pull_count

      field :data_namespaces do
        group :collections
        label 'Namespaces'
        list_fields do
          %w(name slug)
        end
      end

      field :data_flows do
        group :workflows
        label 'Flows'
        list_fields do
          %w(namespace name) #TODO Inlude a description field on Flow model
        end
      end

      field :data_translators do
        group :workflows
        label 'Translators'
        list_fields do
          %w(namespace name type style)
        end
      end

      field :data_events do
        group :workflows
        label 'Events'
        list_fields do
          %w(namespace name _type)
        end
      end

      field :data_algorithms do
        group :workflows
        label 'Algorithms'
        list_fields do
          %w(namespace name description)
        end
      end

      field :data_connection_roles do
        group :api_connectors
        label 'Connection roles'
        list_fields do
          %w(namespace name)
        end
      end

      field :data_webhooks do
        group :api_connectors
        label 'Webhooks'
        list_fields do
          %w(namespace name path method description)
        end
      end

      field :data_connections do
        group :api_connectors
        label 'Connections'
        list_fields do
          %w(namespace name url)
        end
      end

      field :data_data_types do
        group :data
        label 'Data types'
        list_fields do
          %w(title name slug _type)
        end
      end

      field :data_schemas do
        group :data
        label 'Schemas'
        list_fields do
          %w(namespace uri)
        end
      end

      field :data_custom_validators do
        group :data
        label 'Custom validators'
        list_fields do
          %w(namespace name _type) #TODO Include a description field for Custom Validator model
        end
      end

      # field :data_data TODO Include collection data field

      field :data_authorizations do
        group :security
        label 'Authorizations'
        list_fields do
          %w(namespace name _type)
        end
      end

      field :data_oauth_providers do
        group :security
        label 'OAuth providers'
        list_fields do
          %w(namespace name response_type authorization_endpoint token_endpoint token_method _type)
        end
      end

      field :data_oauth_clients do
        group :security
        label 'OAuth clients'
        list_fields do
          %w(provider name)
        end
      end

      field :data_oauth2_scopes do
        group :security
        label 'OAuth 2.0 scopes'
        list_fields do
          %w(provider name description)
        end
      end

      field :_id
      field :updated_at
    end
    list do
      field :image do
        thumb_method :icon
      end
      field :name do
        pretty_value do
          bindings[:object].versioned_name
        end
      end
      field :authors
      field :summary
      field :pull_count
      field :dependencies
    end
  end

  config.model Setup::CollectionAuthor do
    visible false
    object_label_method { :label }
    fields :name, :email
  end

  config.model Setup::CollectionPullParameter do
    visible false
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
      field :property_name
      field :location, :json_value
    end
    show do
      field :label
      field :parameter

      field :created_at
      #field :creator
      field :updated_at
    end
    list do
      field :label
      field :parameter
      field :updated_at
    end
    fields :label, :parameter
  end

  config.model Setup::CollectionData do
    visible false
    object_label_method { :label }
  end

  config.model Setup::Collection do
    weight 020
    navigation_label 'Collections'
    register_instance_option :label_navigation do
      'My Collections'
    end

    group :workflows

    configure :flows do
      group :workflows
    end

    configure :events do
      group :workflows
    end

    configure :translators do
      group :workflows
    end

    configure :algorithms do
      group :workflows
    end

    configure :applications do
      group :workflows
    end

    group :api_connectors do
      label 'Connectors'
      active true
    end

    configure :connections do
      group :api_connectors
    end

    configure :webhooks do
      group :api_connectors
    end

    configure :connection_roles do
      group :api_connectors
    end

    group :data

    configure :data_types do
      group :data
    end

    configure :schemas do
      group :data
    end

    configure :data do
      group :data
    end

    configure :custom_validators do
      group :data
    end

    group :security

    configure :authorizations do
      group :security
    end

    configure :oauth_providers do
      group :security
    end

    configure :oauth_clients do
      group :security
    end

    configure :oauth2_scopes do
      group :security
    end

    group :config

    configure :namespaces do
      group :config
    end

    edit do
      field :image
      field :readme do
        visible { Account.current_super_admin? }
      end
      field :name
      field :flows
      field :connection_roles
      field :translators
      field :events
      field :data_types
      field :schemas
      field :custom_validators
      field :algorithms
      field :applications
      field :webhooks
      field :connections
      field :authorizations
      field :oauth_providers
      field :oauth_clients
      field :oauth2_scopes
      field :data
    end

    show do
      field :image
      field :readme, :html_erb
      field :name
      field :flows
      field :connection_roles
      field :translators
      field :events
      field :data_types
      field :schemas
      field :custom_validators
      field :algorithms
      field :applications
      field :webhooks
      field :connections
      field :authorizations
      field :oauth_providers
      field :oauth_clients
      field :oauth2_scopes
      field :data
      field :namespaces

      field :_id
      field :created_at
      #field :creator
      field :updated_at
      #field :updater
    end

    list do
      field :image do
        thumb_method :icon
      end
      field :name
      field :flows do
        pretty_value do
          value.count > 0 ? value.count : '-'
        end
      end
      field :connection_roles do
        pretty_value do
          value.count > 0 ? value.count : '-'
        end
      end
      field :translators do
        pretty_value do
          value.count > 0 ? value.count : '-'
        end
      end
      field :events do
        pretty_value do
          value.count > 0 ? value.count : '-'
        end
      end
      field :data_types do
        pretty_value do
          value.count > 0 ? value.count : '-'
        end
      end
      field :schemas do
        pretty_value do
          value.count > 0 ? value.count : '-'
        end
      end
      field :custom_validators do
        pretty_value do
          value.count > 0 ? value.count : '-'
        end
      end
      field :algorithms do
        pretty_value do
          value.count > 0 ? value.count : '-'
        end
      end
      field :applications do
        pretty_value do
          value.count > 0 ? value.count : '-'
        end
      end
      field :webhooks do
        pretty_value do
          value.count > 0 ? value.count : '-'
        end
      end
      field :connections do
        pretty_value do
          value.count > 0 ? value.count : '-'
        end
      end
      field :authorizations do
        pretty_value do
          value.count > 0 ? value.count : '-'
        end
      end
      field :oauth_providers do
        pretty_value do
          value.count > 0 ? value.count : '-'
        end
      end
      field :oauth_clients do
        pretty_value do
          value.count > 0 ? value.count : '-'
        end
      end
      field :oauth2_scopes do
        pretty_value do
          value.count > 0 ? value.count : '-'
        end
      end
      field :data
      field :updated_at
    end
  end

  #Definitions

  config.navigation 'Definitions', icon: 'fa fa-puzzle-piece'

  config.model Setup::Validator do
    navigation_label 'Definitions'
    label 'Validators'
    weight 100
    fields :namespace, :name

    fields :namespace, :name, :updated_at

    show_in_dashboard false
  end

  config.model Setup::CustomValidator do
    visible false

    configure :_type do
      pretty_value do
        value.split('::').last.to_title
      end
    end

    list do
      field :namespace
      field :name
      field :_type
      field :updated_at
    end

    fields :namespace, :name, :_type, :updated_at
  end

  config.model Setup::Schema do
    weight 101
    object_label_method { :custom_title }

    edit do
      field :namespace, :enum_edit do
        read_only { !bindings[:object].new_record? }
      end

      field :uri do
        read_only { !bindings[:object].new_record? }
        html_attributes do
          { cols: '74', rows: '1' }
        end
      end

      field :schema, :code_mirror do
        html_attributes do
          { cols: '74', rows: '15' }
        end
        config do
          { lineNumbers: true, theme: 'night' }
        end
      end

      field :schema_data_type do
        inline_edit false
        inline_add false
      end
    end

    show do
      field :namespace
      field :uri
      field :schema do
        pretty_value do
          v =
              if json = JSON.parse(value) rescue nil
                "<code class='json'>#{JSON.pretty_generate(json).gsub('<', '&lt;').gsub('>', '&gt;')}</code>"
              elsif (xml = Nokogiri::XML(value)).errors.blank?
                "<code class='xml'>#{xml.to_xml.gsub('<', '&lt;').gsub('>', '&gt;')}</code>"
              else
                "<code>#{value}</code>"
              end
          "<pre>#{v}</pre>".html_safe
        end
      end
      field :schema_data_type

      field :_id
      field :created_at
      #field :creator
      field :updated_at
      #field :updater

    end

    fields :namespace, :uri, :schema_data_type, :updated_at
  end

  config.model Setup::XsltValidator do
    parent Setup::Validator
    weight 102
    label 'XSLT Validator'
    object_label_method { :custom_title }

    list do
      field :namespace
      field :xslt
      field :updated_at
    end

    fields :namespace, :name, :xslt, :updated_at
  end

  config.model Setup::EdiValidator do
    parent Setup::Validator
    weight 103
    object_label_method { :custom_title }
    label 'EDI Validator'

    edit do
      field :namespace, :enum_edit
      field :name
      field :schema_data_type
      field :content_type
    end

    fields :namespace, :name, :schema_data_type, :content_type, :updated_at
  end

  config.model Setup::AlgorithmValidator do
    parent Setup::Validator
    weight 104
    label 'Algorithm Validator'
    object_label_method { :custom_title }
    edit do
      field :namespace, :enum_edit
      field :name
      field :algorithm
    end

    fields :namespace, :name, :algorithm, :updated_at
  end

  config.model Setup::DataType do
    navigation_label 'Definitions'
    weight 110
    label 'Data Type'
    object_label_method { :custom_title }
    visible true

    show_in_dashboard false

    configure :_type do
      pretty_value do
        value.split('::').last.to_title
      end
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

    configure :slug

    configure :storage_size, :decimal do
      pretty_value do
        if objects = bindings[:controller].instance_variable_get(:@objects)
          unless max = bindings[:controller].instance_variable_get(:@max_storage_size)
            bindings[:controller].instance_variable_set(:@max_storage_size, max = objects.collect { |data_type| data_type.storage_size }.max)
          end
          (bindings[:view].render partial: 'size_bar', locals: { max: max, value: bindings[:object].records_model.storage_size }).html_safe
        else
          bindings[:view].number_to_human_size(value)
        end
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
      field :title, :enum_edit, &shared_non_editable
      field :slug
      field :before_save_callbacks, &shared_non_editable
      field :records_methods, &shared_non_editable
      field :data_type_methods, &shared_non_editable
    end

    list do
      field :namespace
      field :name
      field :slug
      field :_type
      field :used_memory do
        visible { Cenit.dynamic_model_loading? }
        pretty_value do
          unless max = bindings[:controller].instance_variable_get(:@max_used_memory)
            bindings[:controller].instance_variable_set(:@max_used_memory, max = Setup::DataType.fields[:used_memory.to_s].type.new(Setup::DataType.max(:used_memory)))
          end
          (bindings[:view].render partial: 'used_memory_bar', locals: { max: max, value: Setup::DataType.fields[:used_memory.to_s].type.new(value) }).html_safe
        end
      end
      field :storage_size
      field :updated_at
    end

    show do
      field :namespace
      field :name
      field :title
      field :slug
      field :_type
      field :storage_size
      field :schema do
        pretty_value do
          v =
              if json = JSON.pretty_generate(value) rescue nil
                "<code class='json'>#{json.gsub('<', '&lt;').gsub('>', '&gt;')}</code>"
              else
                value
              end

          "<pre>#{v}</pre>".html_safe
        end
      end

      field :_id
      field :created_at
      #field :creator
      field :updated_at
      #field :updater
    end
    fields :namespace, :name, :slug, :_type, :storage_size, :updated_at
  end

  config.model Setup::JsonDataType do
    navigation_label 'Definitions'
    weight 111
    label 'JSON Data Type'
    object_label_method { :custom_title }

    group :behavior do
      label 'Behavior'
      active false
    end

    configure :title

    configure :name do
      read_only { !bindings[:object].new_record? }
    end

    configure :schema, :code_mirror do
      html_attributes do
        { cols: '74', rows: '15' }
      end
      config do
        { lineNumbers: true, theme: 'night'}
      end
      # pretty_value do
      #   "<pre><code class='json'>#{JSON.pretty_generate(value)}</code></pre>".html_safe
      # end
    end

    configure :storage_size, :decimal do
      pretty_value do
        if (objects = bindings[:controller].instance_variable_get(:@objects))
          unless (max = bindings[:controller].instance_variable_get(:@max_storage_size))
            bindings[:controller].instance_variable_set(:@max_storage_size, max = objects.collect { |data_type| data_type.storage_size }.max)
          end
          (bindings[:view].render partial: 'size_bar', locals: { max: max, value: bindings[:object].records_model.storage_size }).html_safe
        else
          bindings[:view].number_to_human_size(value)
        end
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

    configure :slug

    edit do
      field :namespace, :enum_edit, &shared_non_editable
      field :name, &shared_non_editable
      field :schema, :json_schema do
        shared_read_only
        help { 'Required' }
      end
      field :title, &shared_non_editable
      field :slug
      field :before_save_callbacks, &shared_non_editable
      field :records_methods, &shared_non_editable
      field :data_type_methods, &shared_non_editable
    end

    list do
      field :namespace
      field :name
      field :slug
      field :used_memory do
        visible { Cenit.dynamic_model_loading? }
        pretty_value do
          unless (max = bindings[:controller].instance_variable_get(:@max_used_memory))
            bindings[:controller].instance_variable_set(:@max_used_memory, max = Setup::JsonDataType.fields[:used_memory.to_s].type.new(Setup::JsonDataType.max(:used_memory)))
          end
          (bindings[:view].render partial: 'used_memory_bar', locals: { max: max, value: Setup::JsonDataType.fields[:used_memory.to_s].type.new(value) }).html_safe
        end
      end
      field :storage_size
      field :updated_at
    end

    show do
      field :namespace
      field :title
      field :name
      field :slug
      field :storage_size
      field :schema do
        pretty_value do
          "<pre><code class='ruby'>#{JSON.pretty_generate(value)}</code></pre>".html_safe
        end
      end
      field :before_save_callbacks
      field :records_methods
      field :data_type_methods

      field :_id
      field :created_at
      #field :creator
      field :updated_at
      #field :updater
    end

    fields :namespace, :name, :slug, :storage_size, :updated_at
  end

  config.model Setup::FileDataType do
    navigation_label 'Definitions'
    weight 112
    label 'File Data Type'
    object_label_method { :custom_title }

    group :content do
      label 'Content'
    end

    group :behavior do
      label 'Behavior'
      active false
    end

    configure :storage_size, :decimal do
      pretty_value do
        if objects = bindings[:controller].instance_variable_get(:@objects)
          unless max = bindings[:controller].instance_variable_get(:@max_storage_size)
            bindings[:controller].instance_variable_set(:@max_storage_size, max = objects.collect { |data_type| data_type.records_model.storage_size }.max)
          end
          (bindings[:view].render partial: 'size_bar', locals: { max: max, value: bindings[:object].records_model.storage_size }).html_safe
        else
          bindings[:view].number_to_human_size(value)
        end
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

    configure :slug

    edit do
      field :namespace, :enum_edit, &shared_non_editable
      field :name, &shared_non_editable
      field :title, &shared_non_editable
      field :slug
      field :validators, &shared_non_editable
      field :schema_data_type, &shared_non_editable
      field :before_save_callbacks, &shared_non_editable
      field :records_methods, &shared_non_editable
      field :data_type_methods, &shared_non_editable
    end

    list do
      field :namespace
      field :name
      field :slug
      field :validators
      field :schema_data_type
      field :used_memory do
        visible { Cenit.dynamic_model_loading? }
        pretty_value do
          unless max = bindings[:controller].instance_variable_get(:@max_used_memory)
            bindings[:controller].instance_variable_set(:@max_used_memory, max = Setup::JsonDataType.fields[:used_memory.to_s].type.new(Setup::JsonDataType.max(:used_memory)))
          end
          (bindings[:view].render partial: 'used_memory_bar', locals: { max: max, value: Setup::JsonDataType.fields[:used_memory.to_s].type.new(value) }).html_safe
        end
      end
      field :storage_size
      field :updated_at
    end

    show do
      field :title
      field :name
      field :slug
      field :validators
      field :storage_size
      field :schema_data_type

      field :_id
      field :created_at
      #field :creator
      field :updated_at
      #field :updater
    end

    fields :namespace, :name, :slug, :storage_size, :updated_at
  end

  #Connectors

  config.navigation 'Connectors', icon: 'fa fa-plug'

  config.model Setup::Parameter do
    visible false
    object_label_method { :to_s }
    configure :metadata, :json_value
    configure :value
    edit do
      field :name
      field :value
      field :description
      field :metadata
    end
    list do
      field :name
      field :value
      field :description
      field :metadata
      field :updated_at
    end
  end

  config.model Setup::Connection do
    navigation_label 'Connectors'
    weight 200
    object_label_method { :custom_title }

    group :credentials do
      label 'Credentials'
    end

    configure :number, :string do
      label 'Key'
      html_attributes do
        { maxlength: 30, size: 30 }
      end
      group :credentials
      pretty_value do
        (value || '<i class="icon-lock"/>').html_safe
      end
    end

    configure :token, :text do
      html_attributes do
        { cols: '50', rows: '1' }
      end
      group :credentials
      pretty_value do
        (value || '<i class="icon-lock"/>').html_safe
      end
    end

    configure :authorization do
      group :credentials
      inline_edit false
    end

    configure :authorization_handler do
      group :credentials
    end

    group :parameters do
      label 'Parameters & Headers'
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

    edit do
      field(:namespace, :enum_edit, &shared_non_editable)
      field(:name, &shared_non_editable)
      field(:url, &shared_non_editable)

      field :number
      field :token
      field :authorization
      field(:authorization_handler, &shared_non_editable)

      field :parameters
      field :headers
      field :template_parameters
    end

    show do
      field :namespace
      field :name
      field :url

      field :number
      field :token
      field :authorization
      field :authorization_handler

      field :parameters
      field :headers
      field :template_parameters

      field :_id
      field :created_at
      field :updated_at
    end

    list do
      field :namespace
      field :name
      field :url
      field :number
      field :token
      field :authorization
      field :updated_at
    end

    fields :namespace, :name, :url, :number, :token, :authorization, :updated_at
  end

  config.model Setup::ConnectionRole do
    navigation_label 'Connectors'
    weight 210
    label 'Connection Role'
    object_label_method { :custom_title }

    configure :name, :string do
      help 'Requiered.'
      html_attributes do
        { maxlength: 50, size: 50 }
      end
    end
    configure :webhooks do
      nested_form false
    end
    configure :connections do
      nested_form false
    end
    modal do
      field :namespace, :enum_edit
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

    edit do
      field :namespace, :enum_edit
      field :name
      field :webhooks
      field :connections
    end

    fields :namespace, :name, :webhooks, :connections, :updated_at
  end

  config.model Setup::Webhook do
    navigation_label 'Connectors'
    weight 220
    object_label_method { :custom_title }

    configure :metadata, :json_value

    group :credentials do
      label 'Credentials'
    end

    configure :authorization do
      group :credentials
      inline_edit false
    end

    configure :authorization_handler do
      group :credentials
    end

    group :parameters do
      label 'Parameters & Headers'
    end

    configure :path, :string do
      help 'Requiered. Path of the webhook relative to connection URL.'
      html_attributes do
        { maxlength: 255, size: 100 }
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

    edit do
      field(:namespace, :enum_edit, &shared_non_editable)
      field(:name, &shared_non_editable)
      field(:path, &shared_non_editable)
      field(:method, &shared_non_editable)
      field(:description, &shared_non_editable)
      field(:metadata, :json_value, &shared_non_editable)

      field :authorization
      field(:authorization_handler, &shared_non_editable)

      field :parameters
      field :headers
      field :template_parameters
    end

    show do
      field :namespace
      field :name
      field :path
      field :method
      field :description
      field :metadata, :json_value

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

    fields :namespace, :name, :path, :method, :description, :authorization, :updated_at
  end

  #Security

  config.navigation 'Security', icon: 'fa fa-shield'

  config.model Setup::OauthClient do
    navigation_label 'Security'
    label 'OAuth Client'
    weight 300
    object_label_method { :custom_title }

    configure :tenant do
      visible { Account.current_super_admin? }
      read_only { true }
      help ''
    end

    configure :identifier do
      pretty_value do
        (value || '<i class="icon-lock"/>').html_safe
      end
    end

    configure :secret do
      pretty_value do
        (value || '<i class="icon-lock"/>').html_safe
      end
    end

    fields :provider, :name, :identifier, :secret, :tenant, :updated_at
  end

  config.model Setup::BaseOauthProvider do
    navigation_label 'Security'
    weight 310
    object_label_method { :custom_title }
    label 'Provider'

    configure :_type do
      pretty_value do
        value.split('::').last.to_title
      end
    end

    configure :tenant do
      visible { Account.current_super_admin? }
      read_only { true }
      help ''
    end

    configure :namespace, :enum_edit

    list do
      field :namespace
      field :name
      field :_type
      field :response_type
      field :authorization_endpoint
      field :token_endpoint
      field :token_method
      field :tenant
      field :updated_at
    end

    fields :namespace, :name, :_type, :response_type, :authorization_endpoint, :token_endpoint, :token_method, :tenant
  end

  config.model Setup::OauthProvider do
    weight 311
    label 'OAuth 1.0 provider'
    register_instance_option :label_navigation do
      'OAuth 1.0'
    end
    object_label_method { :custom_title }

    configure :tenant do
      visible { Account.current_super_admin? }
      read_only { true }
      help ''
    end

    configure :refresh_token_algorithm do
      visible { bindings[:object].refresh_token_strategy == :custom.to_s }
    end

    edit do
      field :namespace, :enum_edit, &shared_non_editable
      field :name
      field :response_type
      field :authorization_endpoint
      field :token_endpoint
      field :token_method
      field :request_token_endpoint
      field :refresh_token_strategy
      field :refresh_token_algorithm
    end

    fields :namespace, :name, :response_type, :authorization_endpoint, :token_endpoint, :token_method, :request_token_endpoint, :refresh_token_strategy, :refresh_token_algorithm, :tenant, :updated_at
  end

  config.model Setup::Oauth2Provider do
    weight 312
    label 'OAuth 2.0 provider'
    register_instance_option :label_navigation do
      'OAuth 2.0'
    end
    object_label_method { :custom_title }

    configure :tenant do
      visible { Account.current_super_admin? }
      read_only { true }
      help ''
    end

    configure :refresh_token_algorithm do
      visible { bindings[:object].refresh_token_strategy == :custom.to_s }
    end

    edit do
      field :namespace, :enum_edit
      field :name
      field :response_type
      field :authorization_endpoint
      field :token_endpoint
      field :token_method
      field :scope_separator
      field :refresh_token_strategy
      field :refresh_token_algorithm
    end

    fields :namespace, :name, :response_type, :authorization_endpoint, :token_endpoint, :token_method, :scope_separator, :refresh_token_strategy, :refresh_token_algorithm, :tenant, :updated_at
  end

  config.model Setup::Oauth2Scope do
    navigation_label 'Security'
    weight 320
    label 'OAuth 2.0 Scope'
    object_label_method { :custom_title }

    configure :tenant do
      visible { Account.current_super_admin? }
      read_only { true }
      help ''
    end

    fields :provider, :name, :description, :tenant, :updated_at
  end

  config.model Setup::Authorization do
    navigation_label 'Security'
    weight 330
    object_label_method { :custom_title }
    configure :status do
      pretty_value do
        "<span class=\"label label-#{bindings[:object].status_class}\">#{value.to_s.capitalize}</span>".html_safe
      end
    end
    configure :metadata, :json_value
    configure :_type do
      pretty_value do
        value.split('::').last.to_title
      end
    end

    edit do
      field :namespace, :enum_edit
      field :name
      field :metadata
    end

    fields :namespace, :name, :status, :_type, :metadata, :updated_at
    show_in_dashboard false
  end

  config.model Setup::BasicAuthorization do
    weight 331
    register_instance_option :label_navigation do
      'Basic'
    end
    object_label_method { :custom_title }

    configure :status do
      pretty_value do
        "<span class=\"label label-#{bindings[:object].status_class}\">#{value.to_s.capitalize}</span>".html_safe
      end
    end

    configure :metadata, :json_value

    edit do
      field :namespace
      field :name
      field :username
      field :password
      field :metadata
    end

    group :credentials do
      label 'Credentials'
    end

    configure :username do
      group :credentials
    end

    configure :password do
      group :credentials
    end

    show do
      field :namespace
      field :name
      field :status
      field :username
      field :password
      field :metadata
      field :_id
    end

    edit do
      field :namespace, :enum_edit
      field :name
      field :username
      field :password
    end

    fields :namespace, :name, :status, :username, :password, :updated_at
  end

  config.model Setup::OauthAuthorization do
    weight 332
    label 'OAuth 1.0 authorization'
    register_instance_option :label_navigation do
      'OAuth 1.0'
    end
    object_label_method { :custom_title }
    parent Setup::Authorization

    configure :metadata, :json_value

    configure :status do
      pretty_value do
        "<span class=\"label label-#{bindings[:object].status_class}\">#{value.to_s.capitalize}</span>".html_safe
      end
    end

    edit do
      field :namespace, :enum_edit
      field :name
      field :client
      field :parameters
      field :template_parameters
      field :metadata
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

    configure :realm_id do
      group :credentials
    end

    show do
      field :namespace
      field :name
      field :status
      field :client
      field :parameters
      field :template_parameters
      field :metadata
      field :_id

      field :access_token
      field :access_token_secret
      field :realm_id
      field :token_span
      field :authorized_at
    end

    list do
      field :namespace
      field :name
      field :status
      field :client
      field :updated_at
    end

    fields :namespace, :name, :status, :client, :updated_at
  end

  config.model Setup::Oauth2Authorization do
    weight 333
    label 'OAuth 2.0 authorization'
    register_instance_option :label_navigation do
      'OAuth 2.0'
    end
    object_label_method { :custom_title }
    parent Setup::Authorization

    configure :metadata, :json_value

    configure :status do
      pretty_value do
        "<span class=\"label label-#{bindings[:object].status_class}\">#{value.to_s.capitalize}</span>".html_safe
      end
    end

    configure :expires_in do
      pretty_value do
        "#{value}s" if value
      end
    end

    edit do
      field :namespace, :enum_edit
      field :name
      field :client
      field :scopes do
        visible { bindings[:object].ready_to_save? }
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
      field :parameters do
        visible { bindings[:object].ready_to_save? }
      end
      field :template_parameters do
        visible { bindings[:object].ready_to_save? }
      end
      field :metadata
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
      field :status
      field :client
      field :scopes
      field :parameters
      field :template_parameters
      field :metadata
      field :_id

      field :expires_in

      field :id_token
      field :token_type
      field :access_token
      field :token_span
      field :authorized_at
      field :refresh_token

      field :_id
    end

    fields :namespace, :name, :status, :client, :scopes, :updated_at
  end

  config.model Setup::AwsAuthorization do
    weight -334
    object_label_method { :custom_title }

    configure :metadata, :json_value

    configure :status do
      pretty_value do
        "<span class=\"label label-#{bindings[:object].status_class}\">#{value.to_s.capitalize}</span>".html_safe
      end
    end

    edit do
      field :namespace
      field :name
      field :aws_access_key
      field :aws_secret_key
      field :seller
      field :merchant
      field :markets
      field :signature_method
      field :signature_version
      field :metadata
    end

    group :credentials do
      label 'Credentials'
    end

    configure :aws_access_key do
      group :credentials
    end

    configure :aws_secret_key do
      group :credentials
    end

    show do
      field :namespace
      field :name
      field :aws_access_key
      field :aws_secret_key
      field :seller
      field :merchant
      field :markets
      field :signature_method
      field :signature_version
      field :metadata
    end

    list do
      field :namespace
      field :name
      field :aws_access_key
      field :aws_secret_key
      field :seller
      field :merchant
      field :markets
      field :signature_method
      field :signature_version
      field :updated_at
    end

    fields :namespace, :name, :aws_access_key, :aws_secret_key, :seller, :merchant, :markets, :signature_method, :signature_version, :updated_at
  end

  config.model Setup::OauthAccessGrant do
    navigation_label 'Security'
    label 'Access Grants'
    weight 340

    fields :created_at, :application_id, :scope
  end

  #Compute

  config.navigation 'Compute', icon: 'fa fa-cog'


  config.model Setup::AlgorithmParameter do
    visible false
    fields :name, :type, :many, :required, :default
  end

  config.model Setup::CallLink do
    visible false
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

  config.model Setup::Algorithm do
    navigation_label 'Compute'
    weight 400
    object_label_method { :custom_title }

    extra_associations do
      association = Mongoid::Relations::Metadata.new(
          name: :stored_outputs, relation: Mongoid::Relations::Referenced::Many,
          inverse_class_name: Setup::Algorithm.to_s, class_name: Setup::AlgorithmOutput.to_s
      )
      [RailsAdmin::Adapters::Mongoid::Association.new(association, abstract_model.model)]
    end

    edit do
      field :namespace, :enum_edit
      field :name
      field :description
      field :parameters
      field :code, :code_mirror do
        html_attributes do
          { cols: '74', rows: '15' }
        end
        config do
          { lineNumbers: true, theme: 'night'}
        end
        help { 'Required' }
      end
      field :call_links do
        visible { bindings[:object].call_links.present? }
      end
      field :store_output
      field :output_datatype
      field :validate_output
    end
    show do
      field :namespace
      field :name
      field :description
      field :parameters
      field :code do
        pretty_value do
          v = value.gsub('<', '&lt;').gsub('>', '&gt;')
          "<pre><code class='ruby'>#{v}</code></pre>".html_safe
        end
      end
      field :call_links
      field :_id

      field :stored_outputs
    end

    list do
      field :namespace
      field :name
      field :description
      field :parameters
      field :call_links
      field :updated_at
    end

    fields :namespace, :name, :description, :parameters, :call_links
  end

  config.model Setup::Translator do
    navigation_label 'Compute'
    weight 410
    object_label_method { :custom_title }
    register_instance_option(:form_synchronized) do
      if bindings[:object].not_shared?
        [
            :source_data_type,
            :target_data_type,
            :transformation,
            :target_importer,
            :source_exporter,
            :discard_chained_records
        ]
      end
    end

    edit do
      field :namespace, :enum_edit
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
          { cols: '74', rows: '15' }
        end
        config do
          { lineNumbers: true, theme: 'night'}
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

    list do
      field :namespace
      field :name
      field :type
      field :style
      field :mime_type
      field :file_extension
      field :transformation
      field :updated_at
    end

    fields :namespace, :name, :type, :style, :transformation, :updated_at
  end

  config.model Setup::AlgorithmOutput do
    navigation_label 'Compute'
    weight -405
    visible false

    configure :records_count
    configure :input_parameters
    configure :created_at do
      label 'Recorded at'
    end

    extra_associations do
      association = Mongoid::Relations::Metadata.new(
          name: :records, relation: Mongoid::Relations::Referenced::Many,
          inverse_class_name: Setup::AlgorithmOutput.to_s, class_name: Setup::AlgorithmOutput.to_s
      )
      [RailsAdmin::Adapters::Mongoid::Association.new(association, abstract_model.model)]
    end

    show do
      field :created_at
      field :input_parameters
      field :records_count
    end

    fields :created_at, :input_parameters, :records_count
  end

  config.model Setup::Action do
    visible false
    navigation_label 'Compute'
    weight -402
    object_label_method { :to_s }

    fields :method, :path, :algorithm
  end

  config.model Setup::Application do
    navigation_label 'Compute'
    weight 420
    object_label_method { :custom_title }
    visible
    configure :identifier
    configure :registered, :boolean

    edit do
      field :namespace, :enum_edit
      field :name
      field :slug
      field :actions
      field :application_parameters
    end
    list do
      field :namespace
      field :name
      field :slug
      field :registered
      field :actions
      field :application_parameters
      field :updated_at
    end
    fields :namespace, :name, :slug, :identifier, :secret_token, :registered, :actions, :application_parameters
  end

  config.model Setup::ApplicationParameter do
    visible false
    navigation_label 'Compute'
    configure :group, :enum_edit

    list do
      field :name
      field :type
      field :many
      field :group
      field :description
      field :updated_at
    end

    fields :name, :type, :many, :group, :description
  end

  config.model Setup::Snippet do
    navigation_label 'Compute'
    weight 430
    object_label_method { :custom_title }
    visible
    configure :identifier
    configure :registered, :boolean

    edit do
      field :namespace, :enum_edit
      field :name
      field :type
      field :description
      field :code, :code_mirror do
        html_attributes do
          { cols: '74', rows: '15' }
        end
        help { 'Required' }
        config do
          { lineNumbers: true, theme: 'night'}
        end
      end
      field :tags
    end

    show do
      field :namespace, :enum_edit
      field :name
      field :type
      field :description
      field :code do
        pretty_value do
          "<pre><code class='#{bindings[:object].type}'>#{value}</code></pre>".html_safe
        end
      end
      field :tags
    end

    list do
      field :namespace
      field :name
      field :type
      field :tags
    end
    fields :namespace, :name, :type, :description, :code, :tags
  end

  #Workflows

  config.navigation 'Workflows', icon: 'fa fa-cogs'

  config.model Setup::Flow do
    navigation_label 'Workflows'
    weight 500
    object_label_method { :custom_title }
    register_instance_option(:form_synchronized) do
      if bindings[:object].not_shared?
        [
          :custom_data_type,
          :data_type_scope,
          :scope_filter,
          :scope_evaluator,
          :lot_size,
          :connection_role,
          :webhook,
          :response_translator,
          :response_data_type
        ]
      end
    end

    Setup::FlowConfig.config_fields.each do |f|
      configure f.to_sym, Setup::Flow.data_type.schema['properties'][f]['type'].to_sym
    end

    edit do
      field :namespace, :enum_edit, &shared_non_editable
      field :name, &shared_non_editable
      field :event, :optional_belongs_to do
        inline_edit false
        inline_add false
        visible do
          (f = bindings[:object]).not_shared? || f.data_type_scope.present?
        end
      end
      field :translator do
        help I18n.t('admin.form.required')
        shared_read_only
      end
      field :custom_data_type, :optional_belongs_to do
        inline_edit false
        inline_add false
        shared_read_only
        visible do
          f = bindings[:object]
          if (t = f.translator) && t.data_type.nil?
            unless f.data_type
              if f.custom_data_type_selected?
                f.custom_data_type = nil
                f.data_type_scope = nil
              else
                f.custom_data_type = f.event.try(:data_type)
              end
            end
            true
          else
            f.custom_data_type = nil
            false
          end
        end
        required do
          bindings[:object].event.present?
        end
        label do
          if (translator = bindings[:object].translator)
            if [:Export, :Conversion].include?(translator.type)
              I18n.t('admin.form.flow.source_data_type')
            else
              I18n.t('admin.form.flow.target_data_type')
            end
          else
            I18n.t('admin.form.flow.data_type')
          end
        end
      end
      field :data_type_scope do
        shared_read_only
        visible do
          f = bindings[:object]
          #For filter scope
          bindings[:controller].instance_variable_set(:@_data_type, f.data_type)
          bindings[:controller].instance_variable_set(:@_update_field, 'translator_id')
          if f.shared?
            value.present?
          else
            f.event &&
              (t = f.translator) &&
              t.type != :Import &&
              (f.custom_data_type_selected? || f.data_type)
          end
        end
        label do
          if (translator = bindings[:object].translator)
            if [:Export, :Conversion].include?(translator.type)
              I18n.t('admin.form.flow.source_scope')
            else
              I18n.t('admin.form.flow.target_scope')
            end
          else
            I18n.t('admin.form.flow.data_type_scope')
          end
        end
        help I18n.t('admin.form.required')
      end
      field :scope_filter do
        shared_read_only
        visible do
          f = bindings[:object]
          f.scope_symbol == :filtered
        end
        partial 'form_triggers'
        help I18n.t('admin.form.required')
      end
      field :scope_evaluator do
        inline_add false
        inline_edit false
        shared_read_only
        visible do
          f = bindings[:object]
          f.scope_symbol == :evaluation
        end
        associated_collection_scope do
          Proc.new { |scope| scope.where(:parameters.with_size => 1) }
        end
        help I18n.t('admin.form.required')
      end
      field :lot_size do
        shared_read_only
        visible do
          f = bindings[:object]
          (t = f.translator) && t.type == :Export &&
            f.custom_data_type_selected? &&
            (f.event.blank? || f.data_type.blank? || (f.data_type_scope.present? && f.scope_symbol != :event_source))
        end
      end
      field :webhook do
        shared_read_only
        visible do
          f = bindings[:object]
          (t = f.translator) && [:Import, :Export].include?(t.type) &&
            ((f.persisted? || f.custom_data_type_selected? || f.data_type) && (t.type == :Import || f.event.blank? || f.data_type.blank? || f.data_type_scope.present?))
        end
        help I18n.t('admin.form.required')
      end
      field :authorization do
        visible do
          ((f = bindings[:object]).shared? && f.webhook.present?) ||
            (t = f.translator) && [:Import, :Export].include?(t.type) &&
              ((f.persisted? || f.custom_data_type_selected? || f.data_type) && (t.type == :Import || f.event.blank? || f.data_type.blank? || f.data_type_scope.present?))
        end
      end
      field :connection_role do
        visible do
          ((f = bindings[:object]).shared? && f.webhook.present?) ||
            (t = f.translator) && [:Import, :Export].include?(t.type) &&
              ((f.persisted? || f.custom_data_type_selected? || f.data_type) && (t.type == :Import || f.event.blank? || f.data_type.blank? || f.data_type_scope.present?))
        end
      end
      field :before_submit do
        shared_read_only
        visible do
          f = bindings[:object]
          (t = f.translator) && [:Import].include?(t.type) &&
            ((f.persisted? || f.custom_data_type_selected? || f.data_type) && (t.type == :Import || f.event.blank? || f.data_type.blank? || f.data_type_scope.present?))
        end
        associated_collection_scope do
          Proc.new { |scope| scope.where(:parameters.with_size => 1).or(:parameters.with_size => 2) }
        end
      end
      field :response_translator do
        shared_read_only
        visible do
          f = bindings[:object]
          (t = f.translator) && t.type == :Export &&
            f.ready_to_save?
        end
        associated_collection_scope do
          Proc.new { |scope|
            scope.where(type: :Import)
          }
        end
      end
      field :response_data_type do
        inline_edit false
        inline_add false
        shared_read_only
        visible do
          f = bindings[:object]
          (resp_t = f.response_translator) &&
            resp_t.type == :Import &&
            resp_t.data_type.nil?
        end
        help I18n.t('admin.form.required')
      end
      field :discard_events do
        visible do
          f = bindings[:object]
          ((f.translator && f.translator.type == :Import) || f.response_translator.present?) &&
            f.ready_to_save?
        end
        help I18n.t('admin.form.flow.events_wont_be_fired')
      end
      field :active do
        visible do
          f = bindings[:object]
          f.ready_to_save?
        end
      end
      field :notify_request do
        visible do
          f = bindings[:object]
          (t = f.translator) &&
            [:Import, :Export].include?(t.type) &&
            f.ready_to_save?
        end
        help I18n.t('admin.form.flow.notify_request')
      end
      field :notify_response do
        visible do
          f = bindings[:object]
          (t = f.translator) &&
            [:Import, :Export].include?(t.type) &&
            f.ready_to_save?
        end
        help help I18n.t('admin.form.flow.notify_response')
      end
      field :after_process_callbacks do
        shared_read_only
        visible do
          bindings[:object].ready_to_save?
        end
        help I18n.t('admin.form.flow.after_process_callbacks')
        associated_collection_scope do
          Proc.new { |scope|
            scope.where(:parameters.with_size => 1)
          }
        end
      end
    end

    show do
      field :namespace
      field :name
      field :active
      field :event
      field :translator
      field :custom_data_type
      field :data_type_scope
      field :scope_filter
      field :scope_evaluator
      field :lot_size

      field :webhook
      field :authorization
      field :connection_role
      field :before_submit
      field :response_translator
      field :response_data_type

      field :discard_events
      field :notify_request
      field :notify_response
      field :after_process_callbacks

      field :_id
      field :created_at
      #field :creator
      field :updated_at
      #field :updater
    end

    list do
      field :namespace
      field :name
      field :active
      field :event
      field :translator
      field :updated_at
    end

    fields :namespace, :name, :active, :event, :translator, :updated_at
  end

  config.model Setup::Event do
    navigation_label 'Workflows'
    weight 510
    object_label_method { :custom_title }
    visible false

    configure :_type do
      pretty_value do
        value.split('::').last.to_title
      end
    end

    edit do
      field :namespace, :enum_edit
      field :name
    end

    show do
      field :namespace
      field :name
      field :_type

      field :_id
      field :created_at
      #field :creator
      field :updated_at
      #field :updater
    end

    list do
      field :namespace
      field :name
      field :_type
      field :updated_at
    end

    fields :namespace, :name, :_type, :updated_at
  end

  config.model Setup::Observer do
    navigation_label 'Workflows'
    weight 511
    label 'Data Event'
    object_label_method { :custom_title }

    edit do
      field :namespace, :enum_edit
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

    fields :namespace, :name, :data_type, :triggers, :trigger_evaluator, :updated_at
  end

  config.model Setup::Scheduler do
    navigation_label 'Workflows'
    weight 512
    object_label_method { :custom_title }

    configure :expression, :json_value

    edit do
      field :namespace, :enum_edit
      field :name

      field :expression do
        visible true
        label 'Scheduling type'
        help 'Configure scheduler'
        partial :scheduler
        html_attributes do
          { rows: '1' }
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

    list do
      field :namespace
      field :name
      field :expression
      field :activated
      field :updated_at
    end

    fields :namespace, :name, :expression, :activated, :updated_at
  end

  #Monitors

  config.navigation 'Monitors', icon: 'fa fa-heartbeat'

  config.model Setup::Notification do
    navigation_label 'Monitors'
    weight 600
    object_label_method { :label }

    show_in_dashboard false
    configure :created_at

    configure :type do
      pretty_value do
        "<label style='color:#{bindings[:object].color}'>#{value.to_s.capitalize}</label>".html_safe
      end
    end

    configure :message do
      pretty_value do
        "<label style='color:#{bindings[:object].color}'>#{value}</label>".html_safe
      end
    end

    configure :attachment, :storage_file

    list do
      field :created_at do
        visible do
          if account = Account.current
            account.notifications_listed_at = Time.now
          end
          true
        end
      end
      field :type
      field :message
      field :attachment
      field :task
      field :updated_at
    end
  end

  config.model Setup::Task do
    navigation_label 'Monitors'
    weight 610
    object_label_method { :to_s }
    show_in_dashboard false


    configure :attempts_succeded, :text do
      label 'Attempts/Succedded'
    end
    configure :_type do
      pretty_value do
        value.split('::').last.to_title
      end
    end

    edit do
      field :description
    end

    fields :_type, :description, :scheduler, :attempts_succeded, :retries, :progress, :status, :updated_at
  end

  config.model Setup::FlowExecution do
    navigation_label 'Monitors'
    visible false
    object_label_method { :to_s }

    configure :attempts_succeded, :text do
      label 'Attempts/Succedded'
    end

    edit do
      field :description
    end

    fields :flow, :description, :scheduler, :attempts_succeded, :retries, :progress, :status, :notifications, :updated_at
  end

  config.model Setup::DataTypeGeneration do
    navigation_label 'Monitors'
    visible false
    object_label_method { :to_s }

    configure :attempts_succeded, :text do
      label 'Attempts/Succedded'
    end

    edit do
      field :description
    end

    fields :description, :scheduler, :attempts_succeded, :retries, :progress, :status, :notifications, :updated_at
  end

  config.model Setup::DataTypeExpansion do
    navigation_label 'Monitors'
    visible false
    object_label_method { :to_s }

    configure :attempts_succeded, :text do
      label 'Attempts/Succedded'
    end

    edit do
      field :description
    end

    fields :description, :scheduler, :attempts_succeded, :retries, :progress, :status, :notifications, :updated_at
  end

  config.model Setup::Translation do
    navigation_label 'Monitors'
    visible false
    object_label_method { :to_s }

    configure :attempts_succeded, :text do
      label 'Attempts/Succedded'
    end

    edit do
      field :description
    end

    fields :translator, :description, :scheduler, :attempts_succeded, :retries, :progress, :status, :notifications, :updated_at
  end

  config.model Setup::DataImport do
    navigation_label 'Monitors'
    visible false
    object_label_method { :to_s }

    configure :attempts_succeded, :text do
      label 'Attempts/Succedded'
    end

    edit do
      field :description
    end

    fields :translator, :data, :description, :scheduler, :attempts_succeded, :retries, :progress, :status, :notifications, :updated_at
  end

  config.model Setup::Push do
    navigation_label 'Monitors'
    visible false
    object_label_method { :to_s }

    configure :attempts_succeded, :text do
      label 'Attempts/Succedded'
    end

    edit do
      field :description
    end

    fields :source_collection, :shared_collection, :description, :attempts_succeded, :retries, :progress, :status, :notifications, :updated_at
  end

  config.model Setup::BasePull do
    navigation_label 'Monitors'
    visible false
    label 'Pull'
    object_label_method { :to_s }

    configure :attempts_succeded, :text do
      label 'Attempts/Succedded'
    end

    configure :_type do
      pretty_value do
        value.split('::').last.to_title
      end
    end

    edit do
      field :description
    end

    fields :_type, :pull_request, :pulled_request, :description, :scheduler, :attempts_succeded, :retries, :progress, :status, :notifications, :updated_at
  end

  config.model Setup::PullImport do
    navigation_label 'Monitors'
    visible false
    object_label_method { :to_s }

    configure :attempts_succeded, :text do
      label 'Attempts/Succedded'
    end

    configure :data do
      label 'Pull data'
    end

    edit do
      field :description
    end

    fields :data, :pull_request, :pulled_request, :description, :scheduler, :attempts_succeded, :retries, :progress, :status, :notifications, :updated_at
  end

  config.model Setup::SharedCollectionPull do
    navigation_label 'Monitors'
    visible false
    object_label_method { :to_s }

    configure :attempts_succeded, :text do
      label 'Attempts/Succedded'
    end

    edit do
      field :description
    end

    fields :shared_collection, :pull_request, :pulled_request, :description, :scheduler, :attempts_succeded, :retries, :progress, :status, :notifications, :updated_at
  end

  config.model Setup::SchemasImport do
    navigation_label 'Monitors'
    visible false
    object_label_method { :to_s }
    configure :attempts_succeded, :text do
      label 'Attempts/Succedded'
    end
    edit do
      field :description
    end
    fields :base_uri, :data, :description, :scheduler, :attempts_succeded, :retries, :progress, :status, :notifications, :updated_at
  end

  config.model Setup::Deletion do
    navigation_label 'Monitors'
    visible false
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
    fields :deletion_model, :description, :scheduler, :attempts_succeded, :retries, :progress, :status, :notifications, :updated_at
  end

  config.model Setup::AlgorithmExecution do
    navigation_label 'Monitors'
    visible false
    object_label_method { :to_s }
    configure :attempts_succeded, :text do
      label 'Attempts/Succedded'
    end
    edit do
      field :description
    end
    fields :algorithm, :description, :scheduler, :attempts_succeded, :retries, :progress, :status, :notifications, :updated_at
  end

  config.model Setup::Submission do
    navigation_label 'Monitors'
    visible false
    object_label_method { :to_s }
    configure :attempts_succeded, :text do
      label 'Attempts/Succedded'
    end
    edit do
      field :description
    end
    fields :webhook, :connection, :authorization, :description, :scheduler, :attempts_succeded, :retries, :progress, :status, :notifications, :updated_at
  end

  config.model Setup::Storage do
    navigation_label 'Monitors'
    show_in_dashboard false
    weight 620
    object_label_method { :label }

    configure :filename do
      label 'File name'
      pretty_value { bindings[:object].storage_name }
    end

    configure :length do
      label 'Size'
      pretty_value do
        if objects = bindings[:controller].instance_variable_get(:@objects)
          unless max = bindings[:controller].instance_variable_get(:@max_length)
            bindings[:controller].instance_variable_set(:@max_length, max = objects.collect { |storage| storage.length }.reject(&:nil?).max)
          end
          (bindings[:view].render partial: 'size_bar', locals: { max: max, value: bindings[:object].length }).html_safe
        else
          bindings[:view].number_to_human_size(value)
        end
      end
    end

    configure :storer_model, :model do
      label 'Model'
    end

    configure :storer_object, :record do
      label 'Object'
    end

    configure :storer_property do
      label 'Property'
    end

    list do
      field :storer_model
      field :storer_object
      field :storer_property
      field :filename
      field :contentType
      field :length
      field :updated_at
    end

    fields :storer_model, :storer_object, :storer_property, :filename, :contentType, :length
  end

  #Configuration

  config.navigation 'Configuration', icon: 'fa fa-sliders'

  config.model Setup::Namespace do
    navigation_label 'Configuration'
    weight 700
    fields :name, :slug, :updated_at
  end

  config.model Setup::DataTypeConfig do
    navigation_label 'Configuration'
    label 'Data Type Config'
    weight 710
    configure :data_type do
      read_only true
    end
    fields :data_type, :slug, :navigation_link, :updated_at
  end

  config.model Setup::FlowConfig do
    navigation_label 'Configuration'
    label 'Flow Config'
    weight 720
    configure :flow do
      read_only true
    end
    fields :flow, :active, :notify_request, :notify_response, :discard_events
  end

  config.model Setup::ConnectionConfig do
    navigation_label 'Configuration'
    label 'Connection Config'
    weight 730
    configure :connection do
      read_only true
    end
    configure :number do
      label 'Key'
    end
    fields :connection, :number, :token
  end

  config.model Setup::Pin do

    navigation_label 'Configuration'
    weight 740
    object_label_method :to_s

    configure :model, :model
    configure :record, :record

    edit do
      field :record_model do
        label 'Model'
        help 'Required'
      end

      Setup::Pin.models.values.each do |m_data|
        field m_data[:property] do
          inline_add false
          inline_edit false
          help 'Required'
          visible { bindings[:object].record_model == m_data[:model_name] }
          associated_collection_scope do
            field = "#{m_data[:property]}_id".to_sym
            excluded_ids = Setup::Pin.where(field.exists => true).collect(&field)
            unless (pin = bindings[:object]).nil? || pin.new_record?
              excluded_ids.delete(pin[field])
            end
            Proc.new { |scope| scope.where(origin: :shared, :id.nin => excluded_ids) }
          end
        end
      end

      field :version do
        help 'Required'
        visible { bindings[:object].ready_to_save? }
      end
    end

    show do
      field :model

      Setup::Pin.models.values.each do |m_data|
        field m_data[:property]
      end

      field :version
      field :updated_at
    end

    fields :model, :record, :version, :updated_at
  end

  config.model Setup::Binding do
    navigation_label 'Configuration'
    weight 750

    configure :binder_model, :model
    configure :binder, :record
    configure :bind_model, :model
    configure :bind, :record

    fields :binder_model, :binder, :bind_model, :bind, :updated_at
  end

  config.model Setup::ParameterConfig do
    navigation_label 'Configuration'
    label 'Parameter'
    weight 760

    configure :parent_model, :model
    configure :parent, :record

    edit do
      field :parent_model do
        read_only true
        help ''
      end
      field :parent do
        read_only true
        help ''
      end
      field :location do
        read_only true
        help ''
      end
      field :name do
        read_only true
        help ''
      end
      field :value
    end

    fields :parent_model, :parent, :location, :name, :value, :updated_at
  end

  #Administration

  config.navigation 'Administration', icon: 'fa fa-user-secret'

  config.model User do
    weight 800
    navigation_label 'Administration'
    visible { User.current_super_admin? }
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
        visible { Account.current_super_admin? }
      end
      field :roles do
        visible { Account.current_super_admin? }
      end
      field :account do
        label { Account.current_super_admin? ? 'Account' : 'Account settings' }
        help { nil }
      end
      field :password do
        visible { Account.current_super_admin? }
      end
      field :password_confirmation do
        visible { Account.current_super_admin? }
      end
      field :key do
        visible { !bindings[:object].new_record? && Account.current_super_admin? }
      end
      field :authentication_token do
        visible { !bindings[:object].new_record? && Account.current_super_admin? }
      end
      field :confirmed_at do
        visible { !bindings[:object].new_record? && Account.current_super_admin? }
      end
      field :sign_in_count do
        visible { !bindings[:object].new_record? && Account.current_super_admin? }
      end
      field :current_sign_in_at do
        visible { !bindings[:object].new_record? && Account.current_super_admin? }
      end
      field :last_sign_in_at do
        visible { !bindings[:object].new_record? && Account.current_super_admin? }
      end
      field :current_sign_in_ip do
        visible { !bindings[:object].new_record? && Account.current_super_admin? }
      end
      field :last_sign_in_ip do
        visible { !bindings[:object].new_record? && Account.current_super_admin? }
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

    list do
      field :picture do
        thumb_method :icon
      end
      field :name
      field :email
      field :account
      field :roles
      field :key
      field :authentication_token
      field :sign_in_count
      field :created_at
      field :updated_at
    end
  end

  config.model Account do
    weight 810
    navigation_label 'Administration'
    visible { User.current_super_admin? }
    object_label_method { :label }

    configure :_id do
      visible { Account.current_super_admin? }
    end
    configure :name do
      visible { Account.current_super_admin? }
    end
    configure :owner do
      read_only { !Account.current_super_admin? }
      help { nil }
    end
    configure :tenant_account do
      visible { Account.current_super_admin? }
    end
    configure :number do
      visible { Account.current_super_admin? }
    end
    configure :users do
      visible { Account.current_super_admin? }
    end
    configure :notification_level
    configure :time_zone do
      label 'Time Zone'
    end

    fields :_id, :name, :owner, :tenant_account, :number, :users, :notification_level, :time_zone
  end

  config.model Role do
    weight 810
    navigation_label 'Administration'
    visible { User.current_super_admin? }
    configure :users do
      visible { Account.current_super_admin? }
    end
    fields :name, :users
  end

  config.model Setup::SharedName do
    weight 880
    navigation_label 'Administration'
    visible { User.current_super_admin? }

    fields :name, :owners, :updated_at
  end

  config.model Script do
    weight 830
    navigation_label 'Administration'
    visible { User.current_super_admin? }

    edit do
      field :name
      field :description
      field :code, :code_mirror do
        html_attributes do
          { cols: '74', rows: '15' }
        end
        config do
          { lineNumbers: true, theme: 'night' }
        end
      end
    end

    show do
      field :name
      field :description
      field :code do
        pretty_value do
          v = value.gsub('<', '&lt;').gsub('>', '&gt;')
          "<pre><code class='ruby'>#{v}</code></pre>".html_safe
        end
      end
    end

    list do
      field :name
      field :description
      field :code
      field :updated_at
    end

    fields :name, :description, :code, :updated_at
  end

  config.model CenitToken do
    weight 890
    navigation_label 'Administration'
    visible { User.current_super_admin? }
  end

  config.model Setup::DelayedMessage do
    weight 880
    navigation_label 'Administration'
    visible { User.current_super_admin? }
  end

  config.model Setup::SystemNotification do
    weight 880
    navigation_label 'Administration'
    visible { User.current_super_admin? }
  end

  config.model RabbitConsumer do
    weight 850
    navigation_label 'Administration'
    visible { User.current_super_admin? }
    object_label_method { :to_s }

    configure :task_id do
      pretty_value do
        if (executor = (obj = bindings[:object]).executor) && (task = obj.executing_task)
          v = bindings[:view]
          amc = RailsAdmin.config(task.class)
          am = amc.abstract_model
          wording = task.send(amc.object_label_method)
          amc = RailsAdmin.config(Account)
          am = amc.abstract_model
          if (inspect_action = v.action(:inspect, am, executor))
            task_path = v.show_path(model_name: task.class.to_s.underscore.gsub('/', '~'), id: task.id.to_s)
            v.link_to(wording, v.url_for(action: inspect_action.action_name, model_name: am.to_param, id: executor.id, params: { return_to: task_path }))
          else
            wording
          end.html_safe
        end
      end
    end

    list do
      field :channel
      field :tag
      field :executor
      field :task_id
      field :alive
      field :updated_at
    end

    fields :created_at, :channel, :tag, :executor, :task_id, :alive, :created_at, :updated_at
  end

  config.model ApplicationId do
    weight 830
    navigation_label 'Administration'
    visible { User.current_super_admin? }
    label 'Application ID'

    register_instance_option(:discard_submit_buttons) { bindings[:object].instance_variable_get(:@registering) }

    configure :name
    configure :registered, :boolean
    configure :redirect_uris, :json_value

    edit do
      field :oauth_name do
        visible { bindings[:object].instance_variable_get(:@registering) }
      end
      field :redirect_uris do
        visible { bindings[:object].instance_variable_get(:@registering) }
      end
    end

    list do
      field :name
      field :registered
      field :account
      field :identifier
      field :updated_at
    end

    fields :created_at, :name, :registered, :account, :identifier, :created_at, :updated_at
  end

  config.model Setup::ScriptExecution do
    weight 840
    parent { nil }
    navigation_label 'Administration'
    object_label_method { :to_s }
    visible { User.current_super_admin? }

    configure :attempts_succeded, :text do
      label 'Attempts/Succedded'
    end

    edit do
      field :description
    end

    list do
      field :script
      field :description
      field :scheduler
      field :attempts_succeded
      field :retries
      field :progress
      field :status
      field :notifications
      field :updated_at
    end

    fields :script, :description, :scheduler, :attempts_succeded, :retries, :progress, :status, :notifications
  end
end

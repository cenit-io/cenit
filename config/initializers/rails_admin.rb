require 'account'

require 'rails_admin/config'
require 'rails_admin/config_decorator'

[
  RailsAdmin::Config::Actions::DiskUsage,
  RailsAdmin::Config::Actions::SendToFlow,
  RailsAdmin::Config::Actions::SwitchNavigation,
  RailsAdmin::Config::Actions::RenderChart,
  RailsAdmin::Config::Actions::DataType,
  RailsAdmin::Config::Actions::Chart,
  RailsAdmin::Config::Actions::Filters,
  RailsAdmin::Config::Actions::DataEvents,
  RailsAdmin::Config::Actions::Flows,
  RailsAdmin::Config::Actions::Import,
  #RailsAdmin::Config::Actions::EdiExport,
  RailsAdmin::Config::Actions::ImportSchema,
  RailsAdmin::Config::Actions::DeleteAll,
  RailsAdmin::Config::Actions::TranslatorUpdate,
  RailsAdmin::Config::Actions::Convert,
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
  RailsAdmin::Config::Actions::FilterDataType,
  RailsAdmin::Config::Actions::SwitchScheduler,
  RailsAdmin::Config::Actions::SimpleExport,
  RailsAdmin::Config::Actions::Schedule,
  RailsAdmin::Config::Actions::Submit,
  RailsAdmin::Config::Actions::Trash,
  RailsAdmin::Config::Actions::Inspect,
  RailsAdmin::Config::Actions::Copy,
  RailsAdmin::Config::Actions::Cancel,
  RailsAdmin::Config::Actions::Configure,
  RailsAdmin::Config::Actions::SimpleCross,
  RailsAdmin::Config::Actions::BulkCross,
  RailsAdmin::Config::Actions::Regist,
  RailsAdmin::Config::Actions::SharedCollectionIndex,
  RailsAdmin::Config::Actions::EcommerceIndex,
  RailsAdmin::Config::Actions::CleanUp,
  RailsAdmin::Config::Actions::ShowRecords,
  RailsAdmin::Config::Actions::RunScript,
  RailsAdmin::Config::Actions::Play,
  RailsAdmin::Config::Actions::PullImport,
  RailsAdmin::Config::Actions::State,
  RailsAdmin::Config::Actions::Documentation,
  RailsAdmin::Config::Actions::Push,
  RailsAdmin::Config::Actions::Share,
  RailsAdmin::Config::Actions::Reinstall,
  RailsAdmin::Config::Actions::Swagger,
  RailsAdmin::Config::Actions::AlgorithmDependencies,
  RailsAdmin::Config::Actions::RestApi1,
  RailsAdmin::Config::Actions::RestApi2,
  RailsAdmin::Config::Actions::Notifications,
  RailsAdmin::Config::Actions::LinkDataType,
  RailsAdmin::Config::Actions::ImportApiSpec,
  RailsAdmin::Config::Actions::RemoteSharedCollection,
  RailsAdmin::Config::Actions::OpenApiDirectory,
  RailsAdmin::Config::Actions::Collect,
  RailsAdmin::Config::Actions::MemberTraceIndex,
  RailsAdmin::Config::Actions::CollectionTraceIndex,
  RailsAdmin::Config::Actions::DataTypeConfig,
  RailsAdmin::Config::Actions::JsonEdit
].each { |a| RailsAdmin::Config::Actions.register(a) }

[
  RailsAdmin::Config::Actions::Notebooks,
  RailsAdmin::Config::Actions::NotebooksRoot
].each { |a| RailsAdmin::Config::Actions.register(a) } if Cenit.jupyter_notebooks

RailsAdmin::Config::Actions.register(:export, RailsAdmin::Config::Actions::BulkExport)

[
  RailsAdmin::Config::Fields::Types::JsonValue,
  RailsAdmin::Config::Fields::Types::JsonSchema,
  RailsAdmin::Config::Fields::Types::StorageFile,
  RailsAdmin::Config::Fields::Types::EnumEdit,
  RailsAdmin::Config::Fields::Types::Model,
  RailsAdmin::Config::Fields::Types::Record,
  RailsAdmin::Config::Fields::Types::HtmlErb,
  RailsAdmin::Config::Fields::Types::OptionalBelongsTo,
  RailsAdmin::Config::Fields::Types::Code,
  RailsAdmin::Config::Fields::Types::Tag,
  RailsAdmin::Config::Fields::Types::TimeSpan,
  RailsAdmin::Config::Fields::Types::NonEmptyString,
  RailsAdmin::Config::Fields::Types::NonEmptyText,
  RailsAdmin::Config::Fields::Types::MongoffFileUpload,
  RailsAdmin::Config::Fields::Types::Url,
  RailsAdmin::Config::Fields::Types::CenitOauthScope,
  RailsAdmin::Config::Fields::Types::Scheduler,
  RailsAdmin::Config::Fields::Types::CenitAccessScope,
  RailsAdmin::Config::Fields::Types::ContextualBelongsTo,
  RailsAdmin::Config::Fields::Types::SortReverseString,
  RailsAdmin::Config::Fields::Types::AutoComplete,
  RailsAdmin::Config::Fields::Types::ToggleBoolean
].each { |f| RailsAdmin::Config::Fields::Types.register(f) }

require 'rails_admin/config/fields/factories/tag'

module RailsAdmin

  module Config

    class << self

      def navigation(label, options)
        navigation_options[label.to_s] = options
      end

      def navigation_options
        @nav_options ||= {}
      end

      def dashboard_options
        @dashboard_options ||= {}
      end

      def dashboard_groups
        unless @dashboard_groups
          @dashboard_groups = [
            {
              param: 'data',
              label: 'Data',
              icon: 'fa fa-cube',
              sublinks: [
                {
                  param: 'definitions',
                  label: 'Definitions',
                  icon: 'fa fa-puzzle-piece',
                },
                {
                  param: 'files',
                  label: 'Files',
                  icon: 'fa fa-file',
                },
                {
                  param: 'objects',
                  label: 'Objects',
                  icon: 'fa fa-database',
                }
              ]
            },
            {
              param: 'workflows',
              label: 'Workflows',
              icon: 'fa fa-cogs',
              sublinks: %w(Setup::Notification Setup::Flow Setup::EmailChannel Setup::Observer)
            },
            {
              param: 'transforms',
              label: 'Transforms',
              icon: 'fa fa-random',
              sublinks: %w(Setup::Template Setup::Renderer Setup::Parser Setup::Converter Setup::Updater)
            },
            {
              param: 'gateway',
              label: 'Gateway',
              icon: 'fa fa-hdd-o',
              externals: ['open_api_directory'],
              sublinks: [
                'Setup::ApiSpec',
                {
                  param: 'open_api_directory',
                  label: 'OpenAPI Directory',
                  link: { rel: 'open_api_directory' } # use for example {external: 'http://www.jslint.com/'} in case of external url
                },
                {
                  param: 'connectors',
                  label: 'Connectors',
                  icon: 'fa fa fa-plug'
                }
              ]
            },
            {
              param: 'compute',
              label: 'Compute',
              icon: 'fa fa-cog',
              externals: ['Setup::Notebook'],
              sublinks: %w(Setup::Algorithm Setup::Application Setup::Snippet Setup::Filter)
            },
            {
              param: 'integrations',
              label: 'Integrations',
              icon: 'fa fa-puzzle-piece',
              externals: ['Setup::CrossSharedCollection'],
              sublinks: %w(Setup::Collection Setup::CrossSharedCollection)
            },
            {
              param: 'security',
              label: 'Security',
              icon: 'fa fa-shield',
              externals: [],
              sublinks: %w(Setup::RemoteOauthClient Setup::BaseOauthProvider Setup::Oauth2Scope Setup::Authorization Cenit::OauthAccessGrant )
            }
          ]
          @dashboard_groups.select { |g| g[:param] == 'compute' }.each do |g|
            nb= 'Setup::Notebook'
            sublinks = g[:sublinks]
            unless (sublinks.include?(nb))
              if Cenit.jupyter_notebooks
                g[:sublinks]<< 'Setup::Notebook'
              end
            end
          end
        end
        ecommerce_models = []
        Setup::Configuration.ecommerce_data_types.each do |data_type|
          ecommerce_models << data_type.data_type_name
        end
        if ecommerce_models.present?
          @dashboard_groups + [{
            param: 'ecommerce',
            label: 'eCommerce',
            icon: 'fa fa-shopping-cart',
            sublinks: ecommerce_models
          }]
        else
          @dashboard_groups
        end
      end
    end
  end
end

RailsAdmin.config do |config|

  config.parent_controller = '::ApplicationController'

  config.total_columns_width = 900

  ## == PaperTrail ==
  # config.audit_with :paper_trail, 'User', 'PaperTrail::Version' # PaperTrail >= 3.0.0

  ### More at https://github.com/sferik/rails_admin/wiki/Base-configuration
  config.authenticate_with do
    warden.authenticate! scope: :user unless %w(dashboard shared_collection_index ecommerce_index index show notebooks_root open_api_directory).include?(action_name)
  end
  config.current_user_method { current_user }
  config.authorize_with :cancan

  config.excluded_models += [Setup::BaseOauthAuthorization, Setup::AwsAuthorization]

  config.navigation 'Collections', icon: 'fa fa-cubes'

  Setup::Tag

  Setup::CrossCollectionAuthor

  Setup::CrossCollectionPullParameter

  Setup::CrossSharedCollection

  Setup::CollectionData

  Setup::Collection

  #Definitions

  config.navigation 'Definitions', icon: 'fa fa-puzzle-piece'

  Setup::Validator

  Setup::CustomValidator

  Setup::Schema

  Setup::XsltValidator

  Setup::EdiValidator

  Setup::AlgorithmValidator

  Setup::DataType

  Setup::JsonDataType

  Setup::FileDataType

  Setup::CenitDataType

  #Gateway

  config.navigation 'Gateway', icon: 'fa fa-hdd-o'

  Setup::ApiSpec

  #Connectors

  config.navigation 'Connectors', icon: 'fa fa-plug'

  Setup::Connection

  Setup::ConnectionRole

  Setup::Section

  Setup::Resource

  Setup::Webhook

  Setup::Operation

  Setup::Representation

  Setup::PlainWebhook

  #Security

  config.navigation 'Security', icon: 'fa fa-shield'

  Setup::OauthClient

  Setup::RemoteOauthClient

  Setup::BaseOauthProvider

  Setup::OauthProvider

  Setup::Oauth2Provider

  Setup::SmtpProvider

  Setup::Oauth2Scope

  Setup::Authorization

  Setup::BasicAuthorization

  Setup::OauthAuthorization

  Setup::Oauth2Authorization

  Setup::AwsAuthorization

  Cenit::OauthAccessGrant

  Setup::SmtpAccount

  #Compute

  config.navigation 'Compute', icon: 'fa fa-cog'


  Setup::AlgorithmParameter

  Setup::CallLink

  Setup::Algorithm

  Setup::AlgorithmOutput

  Setup::Action

  Setup::Application

  Cenit::ApplicationParameter

  Setup::Filter

  Setup::Notebook if Cenit.jupyter_notebooks

  #Transformations

  config.navigation 'Transforms', icon: 'fa fa-random'

  Setup::Translator

  Setup::Template

  Setup::ErbTemplate

  Setup::HandlebarsTemplate

  Setup::LiquidTemplate

  Setup::PrawnTemplate

  Setup::RubyTemplate

  Setup::XsltTemplate

  Setup::ConverterTransformation

  Setup::LiquidConverter

  Setup::HandlebarsConverter

  Setup::RubyConverter

  Setup::MappingConverter

  Setup::LegacyTranslator

  Setup::Renderer

  Setup::Parser

  Setup::Converter

  Setup::Updater

  Setup::AlgorithmOutput

  Setup::Action

  Setup::Application

  Cenit::ApplicationParameter

  Setup::Snippet

  #Channels

  config.navigation 'Channels', icon: 'fa fa-exchange'

  Setup::EmailChannel

  Setup::SmtpAccount

  Setup::EmailFlow

  #Workflows

  config.navigation 'Workflows', icon: 'fa fa-cogs'

  Setup::Flow

  Setup::Notification

  Setup::EmailNotification

  Setup::WebHookNotification

  Setup::Event

  Setup::Observer

  Setup::Scheduler

  #Monitors

  config.navigation 'Monitors', icon: 'fa fa-heartbeat', break_line: true

  Mongoid::Tracer::Trace

  Setup::SystemNotification

  Setup::Task

  Setup::Execution

  Setup::FlowExecution

  Setup::DataTypeGeneration

  Setup::DataTypeExpansion

  Setup::Translation

  Setup::DataImport

  Setup::Push

  Setup::BasePull

  Setup::PullImport

  Setup::SharedCollectionPull

  Setup::ApiPull

  Setup::SchemasImport

  Setup::ApiSpecImport

  Setup::Deletion

  Setup::AlgorithmExecution

  Setup::Submission

  Setup::Crossing

  Setup::FileStoreMigration

  Setup::Storage

  #Configuration

  config.navigation 'Configuration', icon: 'fa fa-sliders'

  Setup::Namespace

  Setup::DataTypeConfig

  Setup::FileStoreConfig

  Setup::FlowConfig

  Setup::ConnectionConfig

  Setup::Pin

  Setup::Binding

  Setup::Parameter

  #Administration

  config.navigation 'Administration', icon: 'fa fa-user-secret'

  Setup::Configuration

  User

  Account

  Role

  Setup::CrossSharedName

  Script

  Cenit::BasicToken

  Cenit::BasicTenantToken

  Setup::TaskToken

  Setup::DelayedMessage

  Setup::SystemReport

  RabbitConsumer

  Cenit::ApplicationId

  Setup::ScriptExecution

  Setup::Category

  config.actions do
    dashboard # mandatory
    # disk_usage
    shared_collection_index
    remote_shared_collection
    open_api_directory
    ecommerce_index
    link_data_type
    index # mandatory
    swagger { only [Setup::ApiSpec] }
    new
    filters
    data_events
    notifications
    flows
    import
    import_schema
    import_api_spec
    pull_import
    translator_update
    convert
    export
    bulk_delete
    show
    show_records
    data_type_config
    run
    run_script
    edit
    json_edit
    configure
    play
    copy
    share
    simple_cross
    bulk_cross
    build_gem
    pull
    push
    download_file
    process_flow
    authorize
    simple_generate
    bulk_generate
    simple_expand
    bulk_expand
    records
    filter_data_type
    switch_navigation
    render_chart
    switch_scheduler
    chart
    simple_export
    schedule
    state
    retry_task
    submit
    inspect
    cancel
    regist
    reinstall
    simple_delete_data_type
    bulk_delete_data_type
    collect
    delete
    trash
    notebooks_root if Cenit.jupyter_notebooks
    clean_up
    #show_in_app
    send_to_flow
    delete_all
    data_type
    member_trace_index
    collection_trace_index
    algorithm_dependencies do
      only { Setup::Algorithm }
    end
    rest_api1
    rest_api2
    documentation
    notebooks if Cenit.jupyter_notebooks
  end
end

require 'account'

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
  RailsAdmin::Config::Actions::Collect
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
  RailsAdmin::Config::Fields::Types::CenitAccessScope,
  RailsAdmin::Config::Fields::Types::ContextualBelongsTo
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
    end
  end
end

RailsAdmin.config do |config|

  config.total_columns_width = 900

  ## == PaperTrail ==
  # config.audit_with :paper_trail, 'User', 'PaperTrail::Version' # PaperTrail >= 3.0.0

  ### More at https://github.com/sferik/rails_admin/wiki/Base-configuration
  config.authenticate_with do
    warden.authenticate! scope: :user unless %w(dashboard shared_collection_index ecommerce_index index show notebooks_root open_api_directory).include?(action_name)
  end
  config.current_user_method { current_user }
  config.audit_with :mongoid_audit
  config.authorize_with :cancan

  config.excluded_models += [Setup::BaseOauthAuthorization, Setup::AwsAuthorization]

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
    run
    run_script
    edit
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
    #history_index
    history_show do
      only do
        [
          Setup::Algorithm,
          Setup::Connection,
          Setup::PlainWebhook,
          Setup::Operation,
          Setup::Resource,
          Setup::Translator,
          Setup::Flow,
          Setup::OauthClient,
          Setup::Oauth2Scope,
          Setup::Snippet
        ] +
          Setup::DataType.class_hierarchy +
          Setup::Validator.class_hierarchy +
          Setup::BaseOauthProvider.class_hierarchy
      end
      visible { only.include?((obj = bindings[:object]).class) && obj.try(:shared?) }
    end
    algorithm_dependencies do
      only do
        Setup::Algorithm
      end
    end
    rest_api1
    rest_api2
    documentation
    notebooks if Cenit.jupyter_notebooks
  end

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

  #Connectors

  config.navigation 'Connectors', icon: 'fa fa-plug'

  Setup::ApiSpec

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

  Setup::Oauth2Scope

  Setup::Authorization

  Setup::BasicAuthorization

  Setup::OauthAuthorization

  Setup::Oauth2Authorization

  Setup::AwsAuthorization

  Cenit::OauthAccessGrant

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

  config.navigation 'Transformations', icon: 'fa fa-random'

  Setup::Translator

  Setup::Renderer

  Setup::Parser

  Setup::Converter

  Setup::Updater

  Setup::AlgorithmOutput

  Setup::Action

  Setup::Application

  Cenit::ApplicationParameter

  Setup::Snippet

  #Workflows

  config.navigation 'Workflows', icon: 'fa fa-cogs'

  Setup::Flow

  Setup::Event

  Setup::Observer

  Setup::Scheduler

  #Monitors

  config.navigation 'Monitors', icon: 'fa fa-heartbeat'

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

  Setup::Storage

  #Configuration

  config.navigation 'Configuration', icon: 'fa fa-sliders'

  Setup::Namespace

  Setup::DataTypeConfig

  Setup::FlowConfig

  Setup::ConnectionConfig

  Setup::Pin

  Setup::Binding

  Setup::Parameter

  #Administration

  config.navigation 'Administration', icon: 'fa fa-user-secret'

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
end

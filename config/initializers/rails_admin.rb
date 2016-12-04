require 'account'

[
  RailsAdmin::Config::Actions::DiskUsage,
  RailsAdmin::Config::Actions::SendToFlow,
  RailsAdmin::Config::Actions::SwitchNavigation,
  RailsAdmin::Config::Actions::DataType,
  RailsAdmin::Config::Actions::Filters,
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
  RailsAdmin::Config::Actions::StoreIndex,
  RailsAdmin::Config::Actions::BulkPull,
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
  RailsAdmin::Config::Actions::RestApi,
  RailsAdmin::Config::Actions::LinkDataType
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
  RailsAdmin::Config::Fields::Types::OptionalBelongsTo,
  RailsAdmin::Config::Fields::Types::Code,
  RailsAdmin::Config::Fields::Types::Tag
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
    warden.authenticate! scope: :user unless %w(dashboard shared_collection_index store_index index show).include?(action_name)
  end
  config.current_user_method { current_user }
  config.audit_with :mongoid_audit
  config.authorize_with :cancan

  config.excluded_models += [Setup::BaseOauthAuthorization, Setup::AwsAuthorization]

  config.actions do
    dashboard # mandatory
    # disk_usage
    shared_collection_index
    store_index
    link_data_type
    index # mandatory
    new { except [Setup::Event, Setup::DataType, Setup::Authorization, Setup::BaseOauthProvider] }
    filters
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
    swagger { only [Setup::Api] }
    configure
    play
    copy
    share
    simple_cross
    bulk_cross
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
    filter_data_type
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
    reinstall
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
    rest_api
    documentation
  end

  def shared_read_only
    instance_eval do
      read_only { (obj = bindings[:object]).creator_id != User.current.id && obj.shared? }
    end
  end

  config.navigation 'Collections', icon: 'fa fa-cubes'

# config.model Setup::Tag do
#   visible false
# end

# config.model Setup::CrossCollectionAuthor do
#   visible false
# end

# config.model Setup::CrossCollectionPullParameter do
#   visible false
# end

#  config.model Setup::Collection do
#    weight 000
#  end

#  config.model Setup::CrossSharedCollection do
#    weight 010
#    label 'Shared Collection'
#  end

#  config.model Setup::SharedCollection do
#    weight 020
#    label 'Legacy Shared Collection'
#  end

#  config.model Setup::CollectionAuthor do
#    visible false
#  end

#  config.model Setup::CollectionPullParameter do
#    visible false
#  end

#  config.model Setup::CollectionData do
#    visible false
#  end

  config.navigation 'Definitions', icon: 'fa fa-puzzle-piece'

#  config.model Setup::Validator do
#    weight 100
#    label 'Validators
#  end

#   config.model Setup::CustomValidator do
#     visible false
#   end

#  config.model Setup::Schema do
#    parent Setup::Validator
#    weight 101
#  end

#  config.model Setup::XsltValidator do
#    parent Setup::Validator
#    weight 102
#    label 'XSLT Validator'
#  end

#  config.model Setup::EdiValidator do
#    parent Setup::Validator
#    weight 103
#    label 'EDI Validator'
#  end

#  config.model Setup::AlgorithmValidator do
#    parent Setup::Validator
#    weight 104
#    label 'Algorithm Validator'
#  end

#  config.model Setup::DataType do
#    weight 110
#    label 'Data Type'
#  end

#  config.model Setup::JsonDataType do
#    weight 111
#    label 'Object Type'
#  end

#  config.model Setup::FileDataType do
#    weight 112
#    label 'File Type'
#  end

#  config.model Setup::CenitDataType do
#    navigation_label 'Definitions'
#    weight 113
#    label 'Cenit Type'
#  end

  config.navigation 'Connectors', icon: 'fa fa-plug'

#  config.model Setup::Parameter do
#    visible false
#  end

#  config.model Setup::Api do
#    weight 200
#    label 'API'
#  end

#  config.model Setup::Connection do
#    weight 201
#  end

#  config.model Setup::ConnectionRole do
#    weight 210
#    label 'Connection Role'
#  end

# config.model Setup::Section do
#   weight 210
#   label 'Section'
#   visible false
#  end

# config.model Setup::Webhook do
#   label 'All Webhook'
#   visible false
#  end

#  config.model Setup::Resource do
#    weight 215
#    label 'Resource'
#  end

#  config.model Setup::Operation do
#    weight 217
#  end

#  config.model Setup::Representation do
#    weight 218
#    visible false
#  end

  config.navigation 'Security', icon: 'fa fa-shield'

#  config.model Setup::OauthClient do
#    label 'OAuth Client'
#    weight 300
#  end

#  config.model Setup::BaseOauthProvider do
#    weight 310
#    label 'Provider'
#  end

#  config.model Setup::OauthProvider do
#    weight 311
#    label 'OAuth 1.0 provider'
#  end

#  config.model Setup::Oauth2Provider do
#    weight 312
#    label 'OAuth 2.0 provider'
#  end

#  config.model Setup::Oauth2Scope do
#    weight 320
#    label 'OAuth 2.0 Scope'
#  end

#  config.model Setup::Authorization do
#    weight 330
#  end

#  config.model Setup::BasicAuthorization do
#    weight 331
#  end

#  config.model Setup::OauthAuthorization do
#    weight 332
#    label 'OAuth 1.0 authorization'
#    parent Setup::Authorization
#  end

#  config.model Setup::Oauth2Authorization do
#    weight 333
#    label 'OAuth 2.0 authorization'
#    parent Setup::Authorization
#  end

#  config.model Setup::AwsAuthorization do
#    weight -334
#  end

#  config.model Cenit::OauthAccessGrant do
#    label 'Access Grants'
#    weight 340
#  end

  config.navigation 'Compute', icon: 'fa fa-cog'

#  config.model Setup::AlgorithmParameter do
#    visible false
#  end

#  config.model Setup::CallLink do
#    visible false
#  end

#  config.model Setup::Algorithm do
#    weight 400
#  end

#  config.model Setup::AlgorithmOutput do
#    weight -405
#    visible false
#  end

#  config.model Setup::Action do
#    visible false
#    weight -402
#  end

#  config.model Setup::Application do
#    weight 420
#  end

#  config.model Cenit::ApplicationParameter do
#  end

#  config.model Setup::Snippet do
#    weight 430
#  end

#  config.model Setup::Filter do
#    weight 435
#    label 'Filter'
#  end

  config.navigation 'Transformations', icon: 'fa fa-random'

#  config.model Setup::Translator do
#    label 'Transformation'
#    visible false
#    weight 410
#  end

#  config.model Setup::Renderer do
#    weight 411
#  end

#  config.model Setup::Parser do
#    weight 412
#  end

#  config.model Setup::Converter do
#    weight 413
#  end

#  config.model Setup::Updater do
#    weight 414
#  end

  config.navigation 'Workflows', icon: 'fa fa-cogs'

#  config.model Setup::Flow do
#    weight 500
#  end

#  config.model Setup::Event do
#    weight 510
#    visible false
#  end

# config.model Setup::Observer do
#   weight 511
#   label 'Data Event'
# end

#  config.model Setup::Scheduler do
#    weight 512
#  end

#  config.model Setup::PlainWebhook do
#    label 'Webhook'
#    weight 515
#  end

  config.navigation 'Monitors', icon: 'fa fa-heartbeat'

#  config.model Setup::Notification do
#    weight 600
#  end

#  config.model Setup::Task do
#    weight 610
#  end

#  config.model Setup::FlowExecution do
#    visible false
#  end

#  config.model Setup::DataTypeGeneration do
#    visible false
#  end

#  config.model Setup::DataTypeExpansion do
#    visible false
#  end

#  config.model Setup::Translation do
#    visible false
#  end

#  config.model Setup::DataImport do
#    visible false
#  end

#  config.model Setup::Push do
#    visible false
#  end

#  config.model Setup::BasePull do
#    visible false
#    label 'Pull'
#  end

#  config.model Setup::PullImport do
#    visible false
#  end

#  config.model Setup::SharedCollectionPull do
#    visible false
#  end

#  config.model Setup::ApiPull do
#    visible false
#  end

#  config.model Setup::SchemasImport do
#    visible false
#  end

#  config.model Setup::Deletion do
#    visible false
#  end

#  config.model Setup::AlgorithmExecution do
#    visible false
#  end

#  config.model Setup::Submission do
#    visible false
#  end

#  config.model Setup::Crossing do
#    visible false
#  end

#  config.model Setup::Storage do
#    show_in_dashboard false
#    weight 620
#  end

  config.navigation 'Configuration', icon: 'fa fa-sliders'

#  config.model Setup::Namespace do
#    weight 700
#  end

#  config.model Setup::DataTypeConfig do
#    label 'Data Type Config'
#    weight 710
#  end

#  config.model Setup::FlowConfig do
#    label 'Flow Config'
#    weight 720
#  end

#  config.model Setup::ConnectionConfig do
#    label 'Connection Config'
#    weight 730
#  end

#  config.model Setup::Pin do
#    weight 740
#  end

#  config.model Setup::Binding do
#    weight 750
#  end

#  config.model Setup::ParameterConfig do
#    label 'Parameter'
#    weight 760
#  end

  config.navigation 'Administration', icon: 'fa fa-user-secret'

#  config.model User do
#    weight 800
#  end

#  config.model Account do
#    weight 810
#    label 'Tenants'
#  end

#  config.model Role do
#    weight 810
#  end

#  config.model Setup::SharedName do
#    weight 880
#  end

#  config.model Setup::CrossSharedName do
#    weight 881
#  end

#  config.model Script do
#    weight 830
#  end

#  config.model Cenit::BasicToken do
#    weight 890
#    label 'Token'
#  end

#  config.model Cenit::BasicTenantToken do
#    weight 890
#    label 'Tenant token'
#  end

#  config.model Setup::TaskToken do
#    weight 890
#  end

#  config.model Setup::DelayedMessage do
#    weight 880
#  end

#  config.model Setup::SystemNotification do
#    weight 880
#  end

#  config.model RabbitConsumer do
#    weight 850
#  end

#  config.model Cenit::ApplicationId do
#    weight 830
#  end

#  config.model ScriptExecution do
#    weight 840
#  end

#  config.model Setup::Category do
#    weight 850
#  end

#  config.model TourTrack do
#    weight 841
#  end

end

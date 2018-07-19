require 'cancan/model_adapters/mongoff_adapter'
require 'setup/storage'

class Ability
  include CanCan::Ability

  attr_reader :user

  def initialize(user)

    can :access, :rails_admin

    if (@user = user)

      can [:show, :edit, :sudo], User, id: user.id

      root_actions = RailsAdmin::Config::Actions.all(:root).collect(&:authorization_key)

      if user.super_admin?
        can :manage,
            [
              Role,
              User,
              Account,
              Setup::CrossSharedName,
              Cenit::BasicToken,
              Script,
              Setup::DelayedMessage,
              Setup::SystemReport,
              Setup::Operation,
              Setup::Category,
              TourTrack
            ]
        can [:index, :show, :edit], Setup::Configuration
        can :destroy, [Setup::Storage, Setup::CrossSharedCollection]
        can :simple_delete_data_type, Setup::CenitDataType, origin: :cenit
        can :destroy, Setup::CenitDataType, origin: :tmp
        can [:index, :show, :cancel], RabbitConsumer
        can [:index, :edit, :pull, :import], Setup::CrossSharedCollection
        can [:index, :show], Cenit::ApplicationId
        can(:destroy, Cenit::ApplicationId) do |app_id|
          app_id.app.nil?
        end
        can :inspect, Account

        can [:simple_cross, :reinstall], Setup::CrossSharedCollection, installed: true
        can :simple_cross, UNCONDITIONAL_ADMIN_CROSSING_MODELS
      else
        root_actions.delete(:remote_shared_collection)

        cannot :access, [Setup::CrossSharedName, Setup::DelayedMessage, Setup::SystemReport]
        cannot :destroy, Setup::Storage

        can :index, Setup::CrossSharedCollection
        can :pull, Setup::CrossSharedCollection, installed: true
        can [:edit, :destroy], Setup::CrossSharedCollection, owner_id: user.id
        can :reinstall, Setup::CrossSharedCollection, owner_id: user.id, installed: true
        can [:index, :show, :edit, :inspect], Account, :id.in => (user.account_ids || []) + (user.member_account_ids || [])
        can [:destroy, :clean_up], Account, :id.in => user.account_ids - [user.account_id]
        can :new, Account

        can :simple_cross, CROSSING_MODELS_NO_ORIGIN
        can :simple_cross, CROSSING_MODELS_WITH_ORIGIN, :origin.in => [:default, :owner]
      end

      can [:index, :show], Setup::FileStoreConfig

      if user.roles.any? { |role| Cenit.file_stores_roles.include?(role.name) }
        can :edit, Setup::FileStoreConfig
      end

      can root_actions

      can :destroy, Setup::Execution, :status.in => Setup::Task::FINISHED_STATUS

      can :destroy, Setup::Task,
          :status.in => Setup::Task::NON_ACTIVE_STATUS,
          :scheduler_id.in => Setup::Scheduler.where(activated: false).collect(&:id) + [nil]

      @@allowed ||=
        begin
          allowed_hash = Hash.new { |h, k| h[k] = Set.new }
          non_root = []
          RailsAdmin::Config::Actions.all.each do |action|
            unless action.root?
              non_root << action
              if (models = action.only)
                models = [models] unless models.is_a?(Enumerable)
                allowed_hash[action.authorization_key].merge(models)
              end
            end
          end
          Setup::Models.each_excluded_action do |model, excluded_actions|
            non_root.each do |action|
              models = allowed_hash[key = action.authorization_key]
              denied = (excluded_actions.include?(:all) || excluded_actions.include?(action.key))
              if relevant_rules_for_match(action.authorization_key, model).empty? && !denied
                models << model
              elsif denied
                models.delete(model)
              end
            end
          end
          Setup::Models.each_included_action do |model, included_actions|
            non_root.each do |action|
              models = allowed_hash[key = action.authorization_key]
              models << model if included_actions.include?(action.key)
            end
          end
          allowed_hash.each do |key, models|
            allowed_hash[key] = models.reject { |model| models.any? { |m| model < m } }
          end
          {
            each_shared_excluded_action: shared_denied_hash = Hash.new { |h, k| h[k] = [] },
            each_shared_allowed_action: shared_allowed_hash = Hash.new { |h, k| h[k] = [] }
          }.each do |collector_method, hash|
            Setup::Models.send(collector_method) do |model, actions|
              RailsAdmin::Config::Actions.all.each do |action|
                next if action.root? || Setup::Models.excluded_actions_for(model).include?(action.key)
                if actions.include?(action.key)
                  models = allowed_hash[(key = action.authorization_key)]
                  root = model
                  stack = []
                  while root && models.exclude?(root)
                    stack << root
                    root = root.superclass
                    root = nil unless root.include?(Mongoid::Document)
                  end
                  if root
                    while root
                      models.delete(root)
                      if stack.empty?
                        hash[key] << root
                      else
                        models.concat(root.subclasses)
                      end
                      root = stack.pop
                    end
                  else
                    hash[key] << model
                  end
                end
              end
            end
          end
          [
            allowed_hash,
            shared_denied_hash,
            shared_allowed_hash
          ].each do |hash|
            new_hash = {}
            hash.each do |key, models|
              a = (new_hash[models] ||= [])
              a << key
            end
            hash.clear
            new_hash.each do |models, keys|
              if (models = models.to_a).present?
                hash[keys] = models
              end
            end
          end
          [
            allowed_hash,
            shared_denied_hash,
            shared_allowed_hash
          ].each do |hash|
            hash.each do |keys, models|
              keys.delete(:simple_cross)
              if [:pull, :edit, :destroy, :import, :reinstall].any? { |key| keys.include?(key) }
                models.delete(Setup::CrossSharedCollection)
              end
            end
          end
          @@shared_denied = shared_denied_hash
          @@shared_allowed = shared_allowed_hash
          allowed_hash
        end

      @@allowed.each do |keys, models|
        cannot Cenit.excluded_actions, models unless user.super_admin?
        can keys, models
      end

      @@shared_denied.each do |keys, models|
        can keys, models, { 'origin' => 'default' }
      end

      @@shared_allowed.each do |keys, models|
        can keys, models, { '$or' => [{ 'origin' => 'default' }, { 'tenant_id' => user.account.id }] }
      end

      can :manage, Mongoff::Model
      can :manage, Mongoff::Record

    else
      can [:dashboard, :shared_collection_index, :ecommerce_index, :notebooks_root, :open_api_directory]
      can [:index, :show, :pull, :simple_export], Setup::CrossSharedCollection
      can [:index, :show], Setup::Models.all.to_a -
        [
          Account,
          Setup::Namespace,
          Setup::DataTypeConfig,
          Setup::FlowConfig,
          Setup::ConnectionConfig,
          Setup::Pin,
          Setup::Binding,
          Setup::Parameter
        ]
    end
  end

  CROSSING_MODELS_NO_ORIGIN = [Setup::Collection]

  CROSSING_MODELS_WITH_ORIGIN =
    [
      Setup::OauthClient,
      Setup::Oauth2Scope,
      Setup::Algorithm,
      Setup::Resource,
      Setup::Operation,
      Setup::PlainWebhook,
      Setup::Connection,
      Setup::Flow,
      Setup::Snippet,
      Setup::ApiSpec
    ] +
      Setup::Translator.class_hierarchy +
      Setup::BaseOauthProvider.class_hierarchy +
      Setup::DataType.class_hierarchy +
      Setup::Validator.class_hierarchy

  CROSSING_MODELS = CROSSING_MODELS_WITH_ORIGIN + CROSSING_MODELS_NO_ORIGIN

  UNCONDITIONAL_ADMIN_CROSSING_MODELS = CROSSING_MODELS + [Setup::Scheduler]

  ADMIN_CROSSING_MODELS = UNCONDITIONAL_ADMIN_CROSSING_MODELS + [Setup::CrossSharedCollection]

  def can?(action, subject, *extra_args)
    if action == :json_edit
      subject.is_a?(Mongoff::Record) && !subject.is_a?(Mongoff::GridFs::File)
    elsif (action == :simple_cross && crossing_models.exclude?(subject.is_a?(Class) ? subject : subject.class)) ||
      (subject == ScriptExecution && (user.nil? || !user.super_admin?))
      false
    else
      super
    end
  end

  def crossing_models
    if user
      if user.super_admin?
        ADMIN_CROSSING_MODELS
      else
        CROSSING_MODELS
      end
    else
      []
    end
  end
end

require 'cancan/model_adapters/mongoff_adapter'
require 'setup/storage'

class Ability
  include CanCan::Ability

  attr_reader :user
  attr_reader :deferred_abilities

  def initialize(user)
    @deferred_abilities = []

    deferred_abilities <<
      if (@user = user)

        deferred_abilities <<
          if user.super_admin?
            SuperUser
          else
            can [:read, :update], User, id: user.id

            can [:update, :delete], Setup::CrossSharedCollection, owner_id: user.id
            can [:read, :update], Account, { '$or' => [
              { 'owner_id' => user.id },
              { '_id' => { '$in' => user.member_account_ids || [] } }
            ] }
            can :delete, Account, :id.in => user.account_ids - [user.account_id]
            can :delete, ::Cenit::OauthAccessToken
            StandardUser
          end

        if user.roles.any? { |role| Cenit.file_stores_roles.include?(role.name) }
          can :edit, Setup::FileStoreConfig
        end

        creator_id =
          if Account.current && Account.current.owner
            Account.current.owner.id
          else
            user.id
          end

        UserCommon.prepare.const_get(:SHARED_ALLOWED).each do |keys, models|
          can keys, models, { '$or' => [{ 'origin' => 'default' }, { 'creator_id' => creator_id }] }
        end
        UserCommon.prepare
      else
        Anonymous
      end
  end

  CROSSING_MODELS_NO_ORIGIN = [Setup::Collection]

  CROSSING_MODELS_WITH_ORIGIN =
    [
      Setup::RemoteOauthClient,
      Setup::GenericAuthorizationClient,
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
      Setup::AuthorizationProvider.class_hierarchy +
      Setup::DataType.class_hierarchy +
      Setup::Validator.class_hierarchy

  CROSSING_MODELS = CROSSING_MODELS_WITH_ORIGIN + CROSSING_MODELS_NO_ORIGIN

  UNCONDITIONAL_ADMIN_CROSSING_MODELS = CROSSING_MODELS + [Setup::Scheduler]

  ADMIN_CROSSING_MODELS = UNCONDITIONAL_ADMIN_CROSSING_MODELS + [Setup::CrossSharedCollection]

  def can?(action, subject, *extra_args)
    return true if action == :digest
    if action == :json_edit
      subject.is_a?(Mongoff::Record) && !subject.is_a?(Mongoff::GridFs::File)
    elsif (action == :simple_cross && crossing_models.exclude?(subject.is_a?(Class) ? subject : subject.class)) ||
      (subject == ScriptExecution && (user.nil? || !user.super_admin?))
      false
    else
      super || deferred_abilities.any? { |ability| ability.can?(action, subject, *extra_args) }
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

  def relevant_rules_for_query(action, subject)
    [super, deferred_abilities.collect { |ability| ability.get_relevant_rules_for_query(action, subject) }].flatten
  end

  class UserCommon
    extend CanCan::Ability

    can :delete, Setup::Execution, :status.in => Setup::Task::FINISHED_STATUS

    can :delete, Setup::Task,
        :status.in => Setup::Task::NON_ACTIVE_STATUS,
        :scheduler_id.in => Setup::Scheduler.where(activated: false).collect(&:id) + [nil]

    can :read, Setup::FileStoreConfig

    can :manage, Mongoff::Model
    can :manage, Mongoff::Record

    def self.prepare
      return self if @init_done
      @init_done = true

      actions = Setup::Models.all.reduce(Set.new) do |set, model|
        set.merge(model.allowed_actions).merge(model.denied_actions)
      end.merge(Cenit::Access::DEFAULT) - [:all]

      allowed_hash = Hash.new { |h, k| h[k] = Set.new }

      Setup::Models.all.each do |model|
        model_denied = model.denied_actions
        actions.each do |action|
          models = allowed_hash[action]
          denied = model_denied.include?(:all) || model_denied.include?(action)
          if relevant_rules_for_match(action, model).empty? && !denied && model.can?(action)
            models << model
          elsif denied
            models.delete(model)
          end
        end
      end
      Setup::Models.all.each do |model|
        model_allowed = model.allowed_actions
        actions.each do |action|
          models = allowed_hash[action]
          models << model if model_allowed.include?(action)
        end
      end
      allowed_hash.each do |key, models|
        allowed_hash[key] = models.reject { |model| models.any? { |m| model < m } }
      end
      {
        shared_denied_actions: shared_denied_hash = Hash.new { |h, k| h[k] = [] },
        shared_allowed_actions: shared_allowed_hash = Hash.new { |h, k| h[k] = [] }
      }.each do |collector_method, hash|
        Setup::Models.all.each do |model|
          next unless model < Setup::CrossOriginShared
          model.send(collector_method) do |actions|
            actions.each do |action|
              next if model.denied_actions.include?(action)
              if actions.include?(action)
                models = allowed_hash[action]
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
          if [:update, :delete].any? { |key| keys.include?(key) }
            models.delete(Setup::CrossSharedCollection)
          end
        end
      end

      const_set(:ALLOWED, allowed_hash)
      const_set(:SHARED_DENIED, shared_denied_hash)
      const_set(:SHARED_ALLOWED, shared_allowed_hash)

      allowed_hash.each do |keys, models|
        can keys, models
    end

      shared_denied_hash.each do |keys, models|
        can keys, models, { 'origin' => 'default' }
      end
      self
    end
  end

  class StandardUser < self
    extend CanCan::Ability

    cannot :access, [Setup::CrossSharedName, Setup::DelayedMessage, Setup::SystemReport]
    cannot :delete, Setup::Storage

    can :read, Setup::CrossSharedCollection

    # can :simple_cross, CROSSING_MODELS_NO_ORIGIN
    # can :simple_cross, CROSSING_MODELS_WITH_ORIGIN, :origin.in => [:default, :owner]

    can :create, Account unless Cenit.tenant_creation_disabled
  end

  class SuperUser < self
    extend CanCan::Ability

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
    can [:read, :create], Cenit::ActiveTenant
    can [:read, :update], Setup::Configuration
    can :delete, [Setup::Storage, Setup::CrossSharedCollection]
    can :delete, Setup::CenitDataType, origin: :tmp
    can :read, RabbitConsumer
    can :read, :update, Setup::CrossSharedCollection
    can :read, Cenit::ApplicationId
    can(:delete, Cenit::ApplicationId) do |app_id|
      app_id.app.nil?
    end

    # can :simple_cross, Setup::CrossSharedCollection, installed: true
    # can :simple_cross, UNCONDITIONAL_ADMIN_CROSSING_MODELS
  end

  class Anonymous < self
    extend CanCan::Ability

    can :read, Setup::CrossSharedCollection
    can :read, Setup::Models.all.to_a -
      [
        User,
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

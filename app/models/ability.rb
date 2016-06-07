require 'cancan/model_adapters/mongoff_adapter'
require 'setup/storage'

class Ability
  include CanCan::Ability

  def initialize(user)
    can :access, :rails_admin
    if (@user = user)
      cannot :inspect, Account unless user.super_admin?

      can [:show, :edit], Account, id: user.account_id
      can [:show, :edit], User, id: user.id

      @@oauth_models = [Setup::BaseOauthProvider,
                        Setup::OauthProvider,
                        Setup::Oauth2Provider,
                        Setup::OauthClient,
                        Setup::Oauth2Scope]

      can [:index, :show, :edi_export, :simple_export], @@oauth_models
      if user.super_admin?
        can [:destroy, :edit, :create, :import], @@oauth_models
        can :manage, Setup::Application
      else
        can [:destroy, :edit], @@oauth_models, tenant_id: Account.current.id
        cannot :access, Setup::Application
      end

      if user.super_admin?
        can :manage,
            [
              Role,
              User,
              Account,
              Setup::SharedName,
              CenitToken,
              ApplicationId,
              Script,
              Setup::DelayedMessage,
              Setup::SystemNotification
            ]
        can [:import, :edit], Setup::SharedCollection
        can :destroy, [Setup::SharedCollection, Setup::DataType, Setup::Storage]
        can [:index, :show, :cancel], RabbitConsumer
      else
        cannot :access, [Setup::SharedName, Setup::DelayedMessage, Setup::SystemNotification]
        cannot :destroy, [Setup::SharedCollection, Setup::Storage]
      end

      task_destroy_conds =
        {
          'status' => { '$in' => Setup::Task::NOT_RUNNING_STATUS },
          'scheduler_id' => { '$in' => Setup::Scheduler.where(activated: false).collect(&:id) + [nil] }
        }
      can :destroy, Setup::Task, task_destroy_conds


      can RailsAdmin::Config::Actions.all(:root).collect(&:authorization_key)

      can :update, Setup::SharedCollection do |shared_collection|
        shared_collection.owners.include?(user)
      end
      can :edi_export, Setup::SharedCollection

      @@allowed ||=
        begin
          allowed_hash = {}
          non_root = []
          RailsAdmin::Config::Actions.all.each do |action|
            unless action.root?
              if (models = action.only)
                models = [models] unless models.is_a?(Enumerable)
                allowed_hash[action.authorization_key] = Set.new(models)
              else
                non_root << action
              end
            end
          end
          Setup::Models.each_excluded_action do |model, excluded_actions|
            non_root.each do |action|
              models = (allowed_hash[key = action.authorization_key] ||= Set.new)
              models << model if relevant_rules_for_match(action.authorization_key, model).empty? && !(excluded_actions.include?(:all) || excluded_actions.include?(action.key))
            end
          end
          Setup::Models.each_included_action do |model, included_actions|
            non_root.each do |action|
              models = (allowed_hash[key = action.authorization_key] ||= Set.new)
              models << model if included_actions.include?(action.key)
            end
          end
          {
            each_shared_excluded_action: shared_denied_hash = {},
            each_shared_allowed_action: shared_allowed_hash = {}
          }.each do |collector_method, hash|
            puts collector_method
            Setup::Models.send(collector_method) do |model, actions|
              RailsAdmin::Config::Actions.all.each do |action|
                next if action.root?
                if actions.include?(action.key)
                  if (models = (allowed_hash[key = action.authorization_key] ||= Set.new)).any? { |m| m == model || model.subclasses.include?(m) }
                    models.delete_if { |m| m == model || model.subclasses.include?(m) }
                    (hash[key] ||= []) << model
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
          @@shared_denied = shared_denied_hash
          @@shared_allowed = shared_allowed_hash
          allowed_hash
        end

      @@shared_denied.each do |keys, models|
        can keys, models, origin: :default
      end

      @@shared_allowed.each do |keys, models|
        can keys, models, { '$or' => [{ 'origin' => 'default' }, { 'creator_id' => user.id }] }
      end

      @@allowed.each do |keys, models|
        cannot Cenit.excluded_actions, models unless user.super_admin?
        can keys, models
      end

      can :manage, Mongoff::Model
      can :manage, Mongoff::Record

    else
      can [:dashboard, :shared_collection_index]
      can [:index, :show, :grid, :pull, :simple_export], [Setup::SharedCollection]
      can :index, Setup::Models.all.to_a
    end
  end

  def can?(action, subject, *extra_args)
    if subject == ScriptExecution && (@user.nil? || !@user.super_admin?)
      false
    else
      super
    end
  end
end

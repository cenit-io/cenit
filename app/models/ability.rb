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
        can :destroy, [Setup::SharedCollection, Setup::Storage, Setup::CrossSharedCollection]
        can [:index, :show, :cancel], RabbitConsumer
        can [:edit, :pull, :import], Setup::CrossSharedCollection
      else
        cannot :access, [Setup::SharedName, Setup::DelayedMessage, Setup::SystemNotification]
        cannot :destroy, [Setup::SharedCollection, Setup::Storage]
        can :pull, Setup::CrossSharedCollection, installed: true
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
          allowed_hash = Hash.new { |h, k| h[k] = Set.new }
          non_root = []
          RailsAdmin::Config::Actions.all.each do |action|
            unless action.root?
              if (models = action.only)
                models = [models] unless models.is_a?(Enumerable)
                allowed_hash[action.authorization_key].merge(models)
              else
                non_root << action
              end
            end
          end
          Setup::Models.each_excluded_action do |model, excluded_actions|
            non_root.each do |action|
              models = allowed_hash[key = action.authorization_key]
              models << model if relevant_rules_for_match(action.authorization_key, model).empty? && !(excluded_actions.include?(:all) || excluded_actions.include?(action.key))
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
                        models += root.subclasses
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
              if [:pull, :edit, :destroy, :import].any? { |key| keys.include?(key) }
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

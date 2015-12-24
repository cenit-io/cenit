require 'cancan/model_adapters/mongoff_adapter'
require 'setup/storage'

class Ability
  include CanCan::Ability

  def initialize(user)
    if user
      can :access, :rails_admin # only allow admin users to access Rails Admin

      can([:show, :edit], Account) { |a| a.eql?(user.account) }
      can([:show, :edit], User) { |u| u.eql?(user) }

      @@oauth_models = [Setup::BaseOauthProvider,
                        Setup::OauthProvider,
                        Setup::Oauth2Provider,
                        Setup::OauthClient,
                        Setup::Oauth2Scope]

      can [:index, :show, :edi_export, :simple_export], @@oauth_models
      if user.super_admin?
        can [:destroy, :edit, :create], @@oauth_models
      else
        can [:destroy, :edit], @@oauth_models, tenant_id: Account.current.id
      end

      if user.super_admin?
        can :manage,
            [
              Role,
              User,
              Account,
              Setup::SharedName,
              CenitToken,
              Script,
              Setup::Raml,
              Setup::RamlReference,
              Setup::DelayedMessage,
              Setup::SystemNotification
            ]
        can :import, Setup::SharedCollection
        can :destroy, [Setup::SharedCollection, Setup::DataType, Setup::Storage]
      else
        cannot :access, [Setup::SharedName, Setup::DelayedMessage, Setup::SystemNotification]
        cannot :destroy, [Setup::SharedCollection, Setup::Raml, Setup::Storage]
      end

      can :destroy, Setup::Task, Setup::Task.destroy_conditions

      can RailsAdmin::Config::Actions.all(:root).collect(&:authorization_key)

      can :update, Setup::SharedCollection do |shared_collection|
        shared_collection.owners.include?(user)
      end
      can :edi_export, Setup::SharedCollection

      @@setup_map ||=
        begin
          hash = {}
          non_root = []
          RailsAdmin::Config::Actions.all.each do |action|
            unless action.root?
              if models = action.only
                models = [models] unless models.is_a?(Enumerable)
                hash[action.authorization_key] = Set.new(models)
              else
                non_root << action
              end
            end
          end
          Setup::Models.each do |model, excluded_actions|
            non_root.each do |action|
              models = (hash[key = action.authorization_key] ||= Set.new)
              models << model if relevant_rules_for_match(action.authorization_key, model).empty? && !(excluded_actions.include?(:all) || excluded_actions.include?(action.key))
            end
          end
          new_hash = {}
          hash.each do |key, models|
            a = (new_hash[models] ||= [])
            a << key
          end
          hash = {}
          new_hash.each { |models, keys| hash[keys] = models.to_a }
          hash
        end

      @@setup_map.each do |keys, models|
        cannot Cenit.excluded_actions, models unless user.super_admin?
        can keys, models
      end

      models = Setup::SchemaDataType.where(model_loaded: true).collect(&:model)
      models.delete(nil)
      can :manage, models
      can :manage, Mongoff::Model
      can :manage, Mongoff::Record

      file_models = Setup::FileDataType.where(model_loaded: true).collect(&:model)
      file_models.delete(nil)
      can [:index, :show, :upload_file, :download_file, :destroy, :import, :edi_export, :delete_all, :send_to_flow, :data_type], file_models

    else
      can [:index, :show], [Setup::SharedCollection, Setup::Raml, Setup::RamlReference]
    end

  end
end

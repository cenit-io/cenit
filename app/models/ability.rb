class Ability
  include CanCan::Ability

  def initialize(user)
    if user
      can :access, :rails_admin # only allow admin users to access Rails Admin

      can RailsAdmin::Config::Actions.all(:root).collect(&:authorization_key)

      can [:update, :destroy], Setup::SharedCollection, creator: user
      can [:import, :edi_export], Setup::SharedCollection

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
              models << model if relevant_rules_for_match(action.authorization_key, model).empty? && !excluded_actions.include?(action.key)
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

      @@setup_map.each { |keys, models| can keys, models }

      models = Setup::DataType.where(model_loaded: true).collect(&:records_model).select { |m| m.is_a?(Class) }
      can :manage, models

      file_models = Setup::FileDataType.where(model_loaded: true).collect(&:model)
      file_models.delete(nil)
      can [:index, :show, :upload_file, :download_file, :destroy, :import, :edi_export, :delete_all], file_models
    end

  end
end

class Ability
  include CanCan::Ability

  def initialize(user)
    if user
      can :access, :rails_admin # only allow admin users to access Rails Admin

      RailsAdmin::Config::Actions.all(:root).each { |action| can action.authorization_key }

      non_root = RailsAdmin::Config::Actions.all.select { |action| !action.root? }

      can :destroy, Setup::SharedCollection, creator: user
      can :update, Setup::SharedCollection, creator: user
      cannot :pull_collection, Setup::SharedCollection, creator: user

      Setup::Models.each do |model, excluded_actions|
        non_root.each do |action|
          can action.authorization_key, model unless can?(action.authorization_key, model) || excluded_actions.include?(action.key)
        end
      end

      Setup::DataType.all.each do |data_type|
        if (model = data_type.records_model).is_a?(Class)
          can :manage, model
        end
      end
    end

  end
end

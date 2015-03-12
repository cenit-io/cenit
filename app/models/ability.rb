class Ability
  include CanCan::Ability

  def initialize(user)
    if user # allow access to dashboard


      #can :read, :all
      #can :update, User, id: user.id # allows you to edit your own user account
      can :access, :rails_admin # only allow admin users to access Rails Admin
      #can :dashboard
      # if Account.current.owner?(user) or user.has_role?(:admin)
      #   can :manage, :all
      # elsif user.has_role? :superadmin
      #   can :manage, :all # allow superadmins to do anything
      # elsif user.has_role? :manager
      #   #TODO: ADD Dinamic models to manager
      #   can :manage, [Setup::Connection, Setup::Flow, Setup::DataType, Setup::Webhook, Setup::Event]
      # end

      RailsAdmin::Config::Actions.all(:root).each { |action| can action.authorization_key }

      non_root = RailsAdmin::Config::Actions.all.select { |action| !action.root? }

      Setup::Models.each do |model, excluded_actions|
        can :access, model
        non_root.each { |action| can action.authorization_key, model unless excluded_actions.include?(action.key) }
      end

      Setup::DataType.all.each do |data_type|
        if (model = data_type.records_model).is_a?(Class)
          can :manage, model
        end
      end
    end

  end
end

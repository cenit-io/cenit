class Ability
  include CanCan::Ability

  def initialize(user)
    can :read, :all                   # allow everyone to read everything
    
    if user                   # allow access to dashboard
      can :access, :rails_admin       # only allow admin users to access Rails Admin
      can :dashboard
      if Account.current.owner?(user) or user.has_role?(:admin)  
        can :manage, :all
      elsif user.has_role? :superadmin
        can :manage, :all             # allow superadmins to do anything
      elsif user.has_role? :manager
        can :manage, [ Setup::Connection, Setup::Flow, Setup::DataType, Setup::Weebhook, Setup::Event ]
      end
    end

  end
end

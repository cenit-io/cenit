class Ability
  include CanCan::Ability

  def initialize(user)
   can :access, :rails_admin   # grant access to rails_admin
   can :dashboard              # grant access to the dashboard
    
    user ||= User.new # guest user (not logged in)
    if Account.current.owner?(user) or user.has_role? :admin
      can :manage, :all
    else
      can :read, :all
    end
  end
end

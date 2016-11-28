class Membership
  include Mongoid::Document
  include Mongoid::Timestamps

  rolify

  belongs_to :invited_by, class_name: User.name, inverse_of: :invitations
  belongs_to :user, inverse_of: :memberships
  belongs_to :account, inverse_of: :memberships

  ## Invitation
  field :invitation_token, type: String
  field :invitation_created_at, type: Time
  field :invitation_accepted_at, type: Time
end

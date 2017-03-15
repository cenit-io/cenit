class Membership
  include Mongoid::Document
  include Mongoid::Timestamps
  include RailsAdmin::Models::MembershipAdmin

  rolify

  belongs_to :invited_by, class_name: User.name, inverse_of: :invitations
  belongs_to :user, inverse_of: :memberships
  belongs_to :account, inverse_of: :memberships

  ## Invitation
  field :email, type: String
  field :invitation_token, type: String
  field :invitation_accepted_at, type: Time


  validates_presence_of :email

  before_validation :set_user
  def set_user
    self.account = Account.current
    if (u = User.where(email: self.email).first).nil?
      u = User.new(email: self.email)
      u.password = pwd = Devise.friendly_token
      u.password_confirmation= pwd
      u.save!
    end
    self.user = u
  end

  after_create :send_invitation
  def send_invitation
    self.user.invite!(self.invited_by)
  end

  def to_s
    self.account.present? ? self.account.name.split('@')[0] : super
  end
end

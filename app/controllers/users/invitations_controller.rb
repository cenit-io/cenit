class Users::InvitationsController < Devise::InvitationsController
  private
  alias_method :orig_accept_resource, :accept_resource
  def accept_resource
    user = orig_accept_resource
    if (membership = Membership.where(invitation_token: user.invitation_token).first).present?
      membership.update_attributes!(invitation_accepted_at: Time.now)
    end
    user
  end
end

module RailsAdmin
  module Models
    module MembershipAdmin
      extend ActiveSupport::Concern

      included do
        rails_admin do
          weight 810
          navigation_label 'Administration'

          configure :_id do
            visible { Account.current_super_admin? }
          end

          show do
            field :email
            field :invited_by
            field :invitation_token
            field :invitation_accepted_at
          end

          edit do
          end

          fields :email, :invited_by, :invitation_accepted_at
        end
      end

    end
  end
end

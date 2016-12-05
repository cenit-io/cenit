module RailsAdmin
  module Models
    module RoleAdmin
      extend ActiveSupport::Concern

      included do
        rails_admin do
          weight 810
          navigation_label 'Administration'
          visible { User.current_super_admin? }
          configure :users do
            visible { Account.current_super_admin? }
          end
          fields :name, :users
        end

      end
    end
  end
end

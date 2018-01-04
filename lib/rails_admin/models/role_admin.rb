module RailsAdmin
  module Models
    module RoleAdmin
      extend ActiveSupport::Concern

      included do
        rails_admin do
          weight 810
          navigation_label 'Administration'

          visible { User.current_super_admin? }

          configure :metadata, :json_value

          configure :users do
            visible { Account.current_super_admin? }
          end

          fields :name, :metadata, :users
        end

      end
    end
  end
end

module RailsAdmin
  module Models
    module RoleAdmin
      extend ActiveSupport::Concern

      included do
        rails_admin do
          weight 810
          navigation_label 'Administration'

          visible { ::User.current_super_admin? }

          configure :metadata, :json_value do
            visible { ::User.current_super_admin? }
          end

          configure :users do
            visible { ::User.current_super_admin? }
          end

          fields :name, :metadata, :users
        end

      end
    end
  end
end

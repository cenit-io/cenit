module RailsAdmin
  module Models
    module Cenit
      module BasicTenantTokenAdmin
        extend ActiveSupport::Concern

        included do
          rails_admin do
            weight 890
            navigation_label 'Administration'
            label 'Tenant token'
            visible { ::User.current_super_admin? }
          end
        end
      end
    end
  end
end

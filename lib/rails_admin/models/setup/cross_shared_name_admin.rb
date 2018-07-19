module RailsAdmin
  module Models
    module Setup
      module CrossSharedNameAdmin
        extend ActiveSupport::Concern

        included do
          rails_admin do
            weight 881
            navigation_label 'Administration'
            visible { ::User.current_super_admin? }

            fields :name, :owners, :updated_at
          end
        end

      end
    end
  end
end

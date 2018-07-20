module RailsAdmin
  module Models
    module Setup
      module DelayedMessageAdmin
        extend ActiveSupport::Concern

        included do
          rails_admin do
            weight 880
            navigation_label 'Administration'
            visible { ::User.current_super_admin? }
          end
        end

      end
    end
  end
end

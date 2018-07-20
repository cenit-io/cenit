module RailsAdmin
  module Models
    module Setup
      module SystemReportAdmin
        extend ActiveSupport::Concern

        included do
          rails_admin do
            weight 880
            navigation_label 'Administration'
            visible { ::User.current_super_admin? }

            fields :created_at, :type, :message, :attachment
          end
        end

      end
    end
  end
end

module RailsAdmin
  module Models
    module Setup
      module ValidatorAdmin
        extend ActiveSupport::Concern

        included do
          rails_admin do
            weight 100
            navigation_label 'Definitions'
            label 'Validators'
            navigation_icon 'fa fa-check-square-o'
            fields :namespace, :name
            fields :namespace, :name, :updated_at
            show_in_dashboard false
          end
        end

      end
    end
  end
end

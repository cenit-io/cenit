module RailsAdmin
  module Models
    module Setup
      module NamespaceAdmin
        extend ActiveSupport::Concern

        included do
          rails_admin do
            navigation_label 'Configuration'
            weight 700
            visible {true}
            fields :name, :slug, :updated_at

            show_in_dashboard false
          end
        end
      end
    end
  end
end

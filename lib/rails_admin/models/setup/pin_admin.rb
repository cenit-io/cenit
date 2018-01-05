module RailsAdmin
  module Models
    module Setup
      module PinAdmin
        extend ActiveSupport::Concern

        included do
          rails_admin do
            navigation_label 'Configuration'
            weight 740
            visible false
            object_label_method :to_s

            configure :target_model, :model
            configure :target, :record


            fields :target_model, :target, :trace, :created_at

            show_in_dashboard false
          end
        end

      end
    end
  end
end

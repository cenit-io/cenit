module RailsAdmin
  module Models
    module Setup
      module ActionAdmin
        extend ActiveSupport::Concern

        included do
          rails_admin do
            visible false
            navigation_label 'Compute'
            weight -402
            object_label_method { :to_s }

            fields :method, :path, :algorithm
          end
        end
      end
    end
  end
end
